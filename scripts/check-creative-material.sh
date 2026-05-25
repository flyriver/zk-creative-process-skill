#!/usr/bin/env bash
#
# check-creative-material.sh — Validate generated creative material folder (macOS/Linux port)
#
# Checks for required files, contact sheets, and TODO placeholders.

set -euo pipefail

MATERIAL_DIR=""
STRICT=false
JSON_OUT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --material-dir|-d) MATERIAL_DIR="$2"; shift 2 ;;
        --strict)          STRICT=true; shift ;;
        --json)            JSON_OUT=true; shift ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

[[ -n "$MATERIAL_DIR" ]] || { echo "ERROR: --material-dir is required" >&2; exit 1; }
[[ -d "$MATERIAL_DIR" ]] || { echo "ERROR: MaterialDir not found: $MATERIAL_DIR" >&2; exit 1; }

MATERIAL_DIR=$(cd "$MATERIAL_DIR" && pwd)
OUTPUTS_DIR="${MATERIAL_DIR}/outputs"
SYSTEM_DIR="${MATERIAL_DIR}/_system-review-系统复查资料"

declare -a ISSUES

add_issue() {
    local sev="$1" code="$2" msg="$3" path="${4:-}"
    local json_str
    json_str=$(python3 -c "
import json, sys
issue = {'severity': sys.argv[1], 'code': sys.argv[2], 'message': sys.argv[3], 'path': sys.argv[4]}
print(json.dumps(issue, ensure_ascii=False))
" "$sev" "$code" "$msg" "$path")
    ISSUES+=("$json_str")
}

# Required root files
for f in brief.md "product-brief-产品信息.md"; do
    if [[ ! -f "${MATERIAL_DIR}/${f}" ]]; then
        add_issue "error" "missing_required_file" "Missing required file: $f" "${MATERIAL_DIR}/${f}"
    fi
done

# System directory
if [[ ! -d "$SYSTEM_DIR" ]]; then
    add_issue "error" "missing_system_dir" "Missing _system-review-系统复查资料 directory." "$SYSTEM_DIR"
else
    for f in video_metadata.json run-manifest.json frame-index.json ai-input-pack.md; do
        if [[ ! -f "${SYSTEM_DIR}/${f}" ]]; then
            add_issue "error" "missing_system_file" "Missing system file: $f" "${SYSTEM_DIR}/${f}"
        fi
    done
fi

# Contact sheets
STORYBOARD_COUNT=$(find "$MATERIAL_DIR" -maxdepth 1 -name 'keyframes-reference-storyboard-contact-sheet-*.jpg' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$STORYBOARD_COUNT" -eq 0 ]]; then
    add_issue "error" "missing_contact_sheet" "Missing keyframes contact sheet." "$MATERIAL_DIR"
fi

# Reference video
ORIGINAL_COUNT=$(find "$MATERIAL_DIR" -maxdepth 1 -name 'original-*' 2>/dev/null | wc -l | tr -d ' ')
VIDEO_COUNT=$(find "$MATERIAL_DIR" -maxdepth 1 -name 'video-*' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$ORIGINAL_COUNT" -eq 0 && "$VIDEO_COUNT" -eq 0 ]]; then
    add_issue "error" "missing_reference_video" "Missing reference video. Expected original-* for single or video-* for mix." "$MATERIAL_DIR"
fi

# Outputs
if [[ ! -d "$OUTPUTS_DIR" ]]; then
    add_issue "error" "missing_outputs_dir" "Missing outputs directory." "$OUTPUTS_DIR"
else
    SINGLE_OUTPUT1="${OUTPUTS_DIR}/reference-video-storyboard-原视频场景变化分镜.md"
    SINGLE_OUTPUT2="${OUTPUTS_DIR}/creative-script-directions-创意脚本方向.md"
    HAS_SINGLE=false
    [[ -f "$SINGLE_OUTPUT1" && -f "$SINGLE_OUTPUT2" ]] && HAS_SINGLE=true

    SHARED_COUNT=$(find "$OUTPUTS_DIR" -maxdepth 1 -name 'shared-analysis-*.md' 2>/dev/null | wc -l | tr -d ' ')
    HAS_MIX=false
    [[ "$SHARED_COUNT" -gt 0 ]] && HAS_MIX=true

    if ! $HAS_SINGLE && ! $HAS_MIX; then
        add_issue "error" "missing_output_file" "Missing output files. Expected single outputs or shared-analysis-*.md for mix." "$OUTPUTS_DIR"
    fi
fi

# Check for TODO placeholders in non-system markdown files
while IFS= read -r -d '' mdfile; do
    # Skip system dir
    if [[ "$mdfile" == "${SYSTEM_DIR}"* ]]; then
        continue
    fi
    if grep -q 'TODO' "$mdfile" 2>/dev/null; then
        add_issue "warning" "placeholder_text" "Markdown file still contains placeholder text." "$mdfile"
    fi
done < <(find "$MATERIAL_DIR" -name '*.md' -print0 2>/dev/null)

# Count issues
ERRORS=0
WARNINGS=0
for issue_json in "${ISSUES[@]:-}"; do
    [[ -z "$issue_json" ]] && continue
    sev=$(echo "$issue_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['severity'])")
    case "$sev" in
        error)   ERRORS=$((ERRORS + 1)) ;;
        warning) WARNINGS=$((WARNINGS + 1)) ;;
    esac
done

if $STRICT && [[ $WARNINGS -gt 0 ]]; then
    STATUS="failed"
elif [[ $ERRORS -gt 0 ]]; then
    STATUS="failed"
else
    STATUS="passed"
fi

if $JSON_OUT; then
    # Build issues JSON array
    ISSUES_JSON="["
    FIRST=true
    for ij in "${ISSUES[@]:-}"; do
        [[ -z "$ij" ]] && continue
        if $FIRST; then FIRST=false; else ISSUES_JSON+=","; fi
        ISSUES_JSON+="$ij"
    done
    ISSUES_JSON+="]"

    python3 - "$ISSUES_JSON" "$MATERIAL_DIR" "$(date -u +%Y-%m-%dT%H:%M:%S)" "$STATUS" "$ERRORS" "$WARNINGS" <<'PY'
import json
import sys

issues_json, material_folder, checked_at, status, errors, warnings = sys.argv[1:]
result = {
    "material_folder": material_folder,
    "checked_at": checked_at,
    "status": status,
    "errors": int(errors),
    "warnings": int(warnings),
    "issues": json.loads(issues_json),
}
print(json.dumps(result, indent=2, ensure_ascii=False))
PY
else
    echo "Material check: $STATUS"
    echo "Errors: $ERRORS"
    echo "Warnings: $WARNINGS"
    for issue_json in "${ISSUES[@]:-}"; do
        [[ -z "$issue_json" ]] && continue
        echo "$issue_json" | python3 -c "
import json,sys
i=json.load(sys.stdin)
print(f'[{i[\"severity\"]}] {i[\"code\"]}: {i[\"message\"]} {i[\"path\"]}')
"
    done
fi

if [[ $STATUS == "failed" ]]; then
    exit 1
fi
