#!/usr/bin/env bash
#
# process-reference-videos-mix.sh — Multi-video mix mode (macOS/Linux port)
#
# Processes multiple same-direction reference videos into one shared material folder.
# Equivalent to the PowerShell process-reference-videos-mix.ps1.

set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "[$(date '+%H:%M:%S')] $*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

assert_safe_filename_part() {
    local value="$1"
    local field_name="$2"
    [[ -n "$value" ]] || die "${field_name} cannot be empty"
    if [[ "$value" =~ [\\/:*?\<\>\|\"] ]]; then
        die "${field_name} contains invalid filename characters: $value"
    fi
}

# -- argument parsing ------------------------------------------------------

VIDEO_PATHS=()
SLUG=""
NAME=""
BASE_DIR=""
FFMPEG_PATH="ffmpeg"
FFPROBE_PATH="ffprobe"
PRODUCT_BRIEF_PATH=""
MOVE_MODE=false
KEEP_WORK=false
STORYBOARD_FRAMES=8

usage() {
    cat << 'USAGE'
Usage: process-reference-videos-mix.sh [OPTIONS]

Required:
  --videos PATHS         Comma-separated paths to reference videos
  --slug, -s SLUG        Short lowercase-hyphen slug
  --name, -n NAME        Human-readable name with Chinese description

Optional:
  --base-dir, -d DIR     Base creative-materials directory (default: ./creative-materials)
  --ffmpeg PATH          Path to ffmpeg executable
  --ffprobe PATH         Path to ffprobe executable
  --product-brief, -p PATH  Path to existing product-brief.md
  --move                 Move source videos instead of copying
  --keep-work            Keep intermediate keyframes-work/ directory
  --frames, -f N         Number of storyboard frames per video (4-30, default: 8)
  --help, -h             Show this help
USAGE
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --videos)          IFS=',' read -ra VIDEO_PATHS <<< "$2"; shift 2 ;;
        --slug|-s)         SLUG="$2"; shift 2 ;;
        --name|-n)         NAME="$2"; shift 2 ;;
        --base-dir|-d)     BASE_DIR="$2"; shift 2 ;;
        --ffmpeg)          FFMPEG_PATH="$2"; shift 2 ;;
        --ffprobe)         FFPROBE_PATH="$2"; shift 2 ;;
        --product-brief|-p) PRODUCT_BRIEF_PATH="$2"; shift 2 ;;
        --move)            MOVE_MODE=true; shift ;;
        --keep-work)       KEEP_WORK=true; shift ;;
        --frames|-f)       STORYBOARD_FRAMES="$2"; shift 2 ;;
        --help|-h)         usage ;;
        *) die "Unknown argument: $1" ;;
    esac
done

# -- validation ------------------------------------------------------------

[[ ${#VIDEO_PATHS[@]} -ge 2 ]] || die "mix mode requires at least two videos"
[[ -n "$SLUG" ]] || die "--slug is required"
[[ -n "$NAME" ]] || die "--name is required"

if ! [[ "$SLUG" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    die "Slug must be lowercase alphanumeric with hyphens only: $SLUG"
fi
assert_safe_filename_part "$NAME" "Name"

if [[ "$STORYBOARD_FRAMES" -lt 4 || "$STORYBOARD_FRAMES" -gt 30 ]]; then
    die "StoryboardFrames must be between 4 and 30"
fi

# Resolve executables
if ! command -v "$FFMPEG_PATH" &>/dev/null; then
    die "ffmpeg not found. Install: brew install ffmpeg"
fi
if ! command -v "$FFPROBE_PATH" &>/dev/null; then
    die "ffprobe not found. Install: brew install ffmpeg"
fi
FFMPEG=$(command -v "$FFMPEG_PATH")
FFPROBE=$(command -v "$FFPROBE_PATH")

# Determine base dir
if [[ -z "$BASE_DIR" ]]; then
    BASE_DIR="$(pwd)/creative-materials"
fi
mkdir -p "$BASE_DIR"
BASE_DIR=$(cd "$BASE_DIR" && pwd)

# -- folder setup ----------------------------------------------------------

DATE_PREFIX=$(date +%Y-%m-%d)
MATERIAL_DIR="${BASE_DIR}/${DATE_PREFIX}-${SLUG}-${NAME}"
if [[ -d "$MATERIAL_DIR" ]]; then
    die "Material folder already exists: $MATERIAL_DIR"
fi

OUTPUTS_DIR="${MATERIAL_DIR}/outputs"
SYSTEM_DIR="${MATERIAL_DIR}/_system-review-系统复查资料"
WORK_DIR="${MATERIAL_DIR}/keyframes-work"
mkdir -p "$MATERIAL_DIR" "$OUTPUTS_DIR" "$SYSTEM_DIR" "$WORK_DIR"

NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%S)

# -- product brief ---------------------------------------------------------

PRODUCT_BRIEF_OUT="${MATERIAL_DIR}/product-brief-产品信息.md"
if [[ -n "$PRODUCT_BRIEF_PATH" ]]; then
    [[ -f "$PRODUCT_BRIEF_PATH" ]] || die "Product brief not found: $PRODUCT_BRIEF_PATH"
    cp "$PRODUCT_BRIEF_PATH" "$PRODUCT_BRIEF_OUT"
else
    cat > "$PRODUCT_BRIEF_OUT" << 'PRODUCTBRIEF'
# Product Brief

Fill this before asking AI to map the reference videos into your own product.

## Product Basics

- Product/game name: TODO
- Genre/category: TODO
- Target market and audience: TODO
- Platform and ad channel: TODO

## Core Gameplay

- Main loop: TODO
- First 30 seconds of real user experience: TODO
- Core interaction the ad can truthfully show: TODO
- Progression, upgrade, merge, battle, puzzle, building, collection, or other system: TODO

## Sellable Hooks

- Strongest fantasy or desire: TODO
- Visual assets already available: TODO
- Mechanics that can connect to this shared reference direction: TODO
- Emotional payoff after the hook: TODO

## Constraints

- Must show: TODO
- Must avoid: TODO
- Production constraints: TODO
- Compliance/platform constraints: TODO

## Mapping Goal

- Acquisition goal: TODO
- Creative angle to test: TODO
- Success metric: TODO

## Privacy Reminder

Do not include API keys, unreleased financial data, personal information, or private partner data in this file.
PRODUCTBRIEF
fi

# -- process each video ----------------------------------------------------

METADATA_ITEMS="["
FRAME_ITEMS="["
VIDEO_INDEX=0

for VP in "${VIDEO_PATHS[@]}"; do
    VIDEO_INDEX=$((VIDEO_INDEX + 1))
    SOURCE=$(realpath "$VP" 2>/dev/null || readlink -f "$VP" 2>/dev/null || echo "$VP")
    [[ -f "$SOURCE" ]] || die "Video file not found: $VP"

    EXT="${SOURCE##*.}"
    [[ -z "$EXT" || "$EXT" == "$SOURCE" ]] && EXT="mp4"

    BASENAME_NOEXT=$(basename "$SOURCE" | sed 's/\.[^.]*$//')
    DEST_NAME=$(printf "video-%02d-%s.%s" "$VIDEO_INDEX" "$BASENAME_NOEXT" "$EXT")
    DEST="${MATERIAL_DIR}/${DEST_NAME}"

    if $MOVE_MODE; then
        mv "$SOURCE" "$DEST"
    else
        cp "$SOURCE" "$DEST"
    fi
    log "Video $VIDEO_INDEX: ${DEST_NAME}"

    # Probe metadata
    PROBE_JSON=$("$FFPROBE" -v error -print_format json -show_streams -show_format "$DEST" 2>/dev/null) || die "ffprobe failed for $DEST"

    VCODEC=$(echo "$PROBE_JSON" | python3 -c "import json,sys;vs=[s for s in json.load(sys.stdin)['streams'] if s['codec_type']=='video'];print(vs[0]['codec_name'])")
    VWIDTH=$(echo "$PROBE_JSON" | python3 -c "import json,sys;vs=[s for s in json.load(sys.stdin)['streams'] if s['codec_type']=='video'];print(vs[0]['width'])")
    VHEIGHT=$(echo "$PROBE_JSON" | python3 -c "import json,sys;vs=[s for s in json.load(sys.stdin)['streams'] if s['codec_type']=='video'];print(vs[0]['height'])")
    VDURATION=$(echo "$PROBE_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
vs=[s for s in d['streams'] if s['codec_type']=='video']
dur = float(vs[0].get('duration',0) if vs else 0)
if dur==0: dur=float(d.get('format',{}).get('duration',0))
print(round(dur,3))
")

    if [[ $VIDEO_INDEX -gt 1 ]]; then
        METADATA_ITEMS+=","
        FRAME_ITEMS+=","
    fi
    METADATA_ITEM=$(python3 - "$VIDEO_INDEX" "$DEST_NAME" "$VDURATION" "$VWIDTH" "$VHEIGHT" "$VCODEC" <<'PY'
import json
import sys

index, file_name, duration, width, height, codec = sys.argv[1:]
print(json.dumps({
    "index": int(index),
    "file": file_name,
    "duration_seconds": float(duration),
    "width": int(width),
    "height": int(height),
    "codec": codec,
}, ensure_ascii=False))
PY
)
    METADATA_ITEMS+="$METADATA_ITEM"

    # Extract selected frames
    SELECTED_DIR="${WORK_DIR}/selected-$(printf '%02d' "$VIDEO_INDEX")"
    mkdir -p "$SELECTED_DIR"

    START_TIME=0.03
    END_TIME=$(python3 -c "print(max(0.03, $VDURATION - 0.35))")
    FRAMES_ARR="["

    for i in $(seq 0 $((STORYBOARD_FRAMES - 1))); do
        idx=$((i + 1))
        if [[ $STORYBOARD_FRAMES -eq 1 ]]; then
            ratio=0
        else
            ratio=$(python3 -c "print($i / ($STORYBOARD_FRAMES - 1))")
        fi
        timestamp=$(python3 -c "print(round($START_TIME + ($END_TIME - $START_TIME) * $ratio, 3))")
        fname=$(printf "selected-%02d.jpg" "$idx")

        "$FFMPEG" -hide_banner -y \
            -ss "$timestamp" -i "$DEST" \
            -frames:v 1 -q:v 2 \
            -vf 'scale=360:-1' \
            -update 1 \
            "${SELECTED_DIR}/${fname}" \
            > "${WORK_DIR}/ffmpeg-video-$(printf '%02d' "$VIDEO_INDEX")-frame-$(printf '%02d' "$idx").log" 2>&1 \
            || die "Frame extraction failed: video $VIDEO_INDEX frame $idx"

        if [[ $i -gt 0 ]]; then FRAMES_ARR+=","; fi
        FRAMES_ARR+="{\"index\":$idx,\"timestamp_seconds\":$timestamp}"
    done
    FRAMES_ARR+="]"

    # Contact sheet for this video
    SHEET_NAME="keyframes-reference-storyboard-contact-sheet-${NAME}-video-$(printf '%02d' "$VIDEO_INDEX").jpg"
    SHEET="${MATERIAL_DIR}/${SHEET_NAME}"
    ROWS=$(python3 -c "import math; print(math.ceil($STORYBOARD_FRAMES / 4))")

    "$FFMPEG" -hide_banner -y \
        -framerate 1 \
        -i "${SELECTED_DIR}/selected-%02d.jpg" \
        -vf "tile=4x${ROWS}:padding=4:margin=2" \
        -frames:v 1 \
        "$SHEET" \
        > "${WORK_DIR}/ffmpeg-sheet-video-$(printf '%02d' "$VIDEO_INDEX").log" 2>&1 \
        || die "Contact sheet failed for video $VIDEO_INDEX"

    FRAME_ITEM=$(python3 - "$VIDEO_INDEX" "$DEST_NAME" "$SHEET_NAME" "$FRAMES_ARR" <<'PY'
import json
import sys

video_index, video_file, contact_sheet, frames_json = sys.argv[1:]
print(json.dumps({
    "video_index": int(video_index),
    "video_file": video_file,
    "contact_sheet": contact_sheet,
    "frames": json.loads(frames_json),
}, ensure_ascii=False))
PY
)
    FRAME_ITEMS+="$FRAME_ITEM"

    log "  Contact sheet: $SHEET_NAME"
done

METADATA_ITEMS+="]"
FRAME_ITEMS+="]"

# -- write system files ----------------------------------------------------

python3 - "${SYSTEM_DIR}/video_metadata.json" "$NOW_ISO" "$METADATA_ITEMS" <<'PY'
import json
import sys

output_path, generated_at, metadata_items = sys.argv[1:]
meta = {
    "generated_at": generated_at,
    "mode": "mix",
    "videos": json.loads(metadata_items),
}
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(meta, f, indent=2, ensure_ascii=False)
PY

python3 - "${SYSTEM_DIR}/frame-index.json" "$NOW_ISO" "$STORYBOARD_FRAMES" "$FRAME_ITEMS" <<'PY'
import json
import sys

output_path, generated_at, storyboard_frames, frame_items = sys.argv[1:]
fi = {
    "generated_at": generated_at,
    "mode": "mix",
    "frame_count_per_video": int(storyboard_frames),
    "videos": json.loads(frame_items),
}
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(fi, f, indent=2, ensure_ascii=False)
PY

# -- skeleton markdown files -----------------------------------------------

BRIEF_PATH="${MATERIAL_DIR}/brief.md"
cat > "$BRIEF_PATH" << BRIEF
# ${NAME} Mixed Reference Creative Task

## Source Videos

$(python3 - "$METADATA_ITEMS" <<'PY'
import json
import sys

items = json.loads(sys.argv[1])
for v in items:
    print(f'- Video {v["index"]}: {v["file"]}, {v["duration_seconds"]}s, {v["width"]}x{v["height"]}')
PY
)

## Generated Assets

- Per-video keyframe contact sheets are in the material root.
- System files are in \`_system-review-系统复查资料/\`.
- Shared analysis goes in \`outputs/\`.
- Product brief: [product-brief-产品信息.md](product-brief-产品信息.md)

## Shared Direction

TODO: describe the shared hook, theme, or creative direction.

## Product Mapping Context

Fill \`product-brief-产品信息.md\` before mapping this shared direction into your own product.
BRIEF

SHARED_PATH="${OUTPUTS_DIR}/shared-analysis-同方向素材共性拆解.md"
cat > "$SHARED_PATH" << 'SHARED'
# Shared Analysis

## Common Hook

TODO

## Differences Between Videos

TODO

## Transferable Structure

TODO

## Product Mapping

Use `../product-brief-产品信息.md`. If it still contains TODO or lacks product-specific information, list missing questions and mark product mapping as pending.

## Creative Direction Pool

TODO
SHARED

AI_PACK="${SYSTEM_DIR}/ai-input-pack.md"
cat > "$AI_PACK" << AIPACK
# AI Input Pack: ${NAME}

This is a same-direction multi-video batch.

## Files

- Brief: ${BRIEF_PATH}
- Shared analysis: ${SHARED_PATH}
- Product brief: ${PRODUCT_BRIEF_OUT}
- Frame index: ${SYSTEM_DIR}/frame-index.json
- Metadata: ${SYSTEM_DIR}/video_metadata.json

## Rule

Analyze these videos as one direction-level creative task. Do not split them into independent single-video folders.
Use product-brief-产品信息.md for product mapping. If product information is missing, do not invent product facts; output the missing questions and keep product mapping marked as pending.
AIPACK

MANIFEST_PATH="${SYSTEM_DIR}/run-manifest.json"
python3 - "$MANIFEST_PATH" "$NOW_ISO" "$MATERIAL_DIR" "$AI_PACK" "$BRIEF_PATH" "$PRODUCT_BRIEF_OUT" "$SHARED_PATH" "$VIDEO_INDEX" <<'PY'
import json
import sys

output_path, generated_at, material_folder, ai_pack, brief, product_brief, shared_path, video_count = sys.argv[1:]
m = {
    "generated_at": generated_at,
    "mode": "mix",
    "script": "process-reference-videos-mix.sh",
    "material_folder": material_folder,
    "ai_input_pack": ai_pack,
    "brief": brief,
    "product_brief": product_brief,
    "outputs": [shared_path],
    "video_count": int(video_count),
}
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(m, f, indent=2, ensure_ascii=False)
PY

# -- cleanup ---------------------------------------------------------------

if ! $KEEP_WORK; then
    rm -rf "$WORK_DIR"
    log "Cleaned up work directory"
fi

# -- output ----------------------------------------------------------------

log "Done. Material folder: $MATERIAL_DIR"

python3 - "$MATERIAL_DIR" "$AI_PACK" "$BRIEF_PATH" "$PRODUCT_BRIEF_OUT" "$SHARED_PATH" "$MANIFEST_PATH" "$KEEP_WORK" <<'PY'
import json
import sys

material_folder, ai_pack, brief, product_brief, shared_analysis, manifest, keep_work = sys.argv[1:]
result = {
    "material_folder": material_folder,
    "ai_input_pack": ai_pack,
    "brief": brief,
    "product_brief": product_brief,
    "shared_analysis": shared_analysis,
    "manifest": manifest,
    "temp_work_dir_kept": keep_work == "true",
}
print(json.dumps(result, indent=2, ensure_ascii=False))
PY
