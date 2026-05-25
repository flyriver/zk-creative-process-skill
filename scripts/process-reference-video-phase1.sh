#!/usr/bin/env bash
#
# process-reference-video-phase1.sh — Single video processing orchestrator (macOS/Linux port)
#
# Calls start-reference-video.sh and validates output with check-creative-material.sh.
# Equivalent to the PowerShell process-reference-video-phase1.ps1.

set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# -- argument parsing ------------------------------------------------------

VIDEO_PATH=""
SLUG=""
NAME=""
BASE_DIR=""
FFMPEG_PATH=""
FFPROBE_PATH=""
PRODUCT_BRIEF_PATH=""
MOVE_MODE=false
KEEP_WORK=false
STORYBOARD_FRAMES=12
SCENE_THRESHOLD=0.23
STRICT_CHECK=false

usage() {
    cat << 'USAGE'
Usage: process-reference-video-phase1.sh [OPTIONS]

Required:
  --video, -v PATH       Path to reference video file
  --slug, -s SLUG        Short lowercase-hyphen slug (e.g. dragon-flight)
  --name, -n NAME        Human-readable name with Chinese description (e.g. dragon-flight-飞龙换场景)

Optional:
  --base-dir, -d DIR     Base creative-materials directory (default: ./creative-materials)
  --ffmpeg PATH          Path to ffmpeg executable
  --ffprobe PATH         Path to ffprobe executable
  --product-brief, -p PATH  Path to existing product-brief.md
  --move                 Move source video instead of copying
  --keep-work            Keep intermediate keyframes-work/ directory
  --frames, -f N         Number of storyboard frames (4-30, default: 12)
  --threshold, -t VAL    Scene detection threshold (default: 0.23)
  --strict               Enable strict validation (warnings count as errors)
  --help, -h             Show this help
USAGE
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --video|-v)        VIDEO_PATH="$2"; shift 2 ;;
        --slug|-s)         SLUG="$2"; shift 2 ;;
        --name|-n)         NAME="$2"; shift 2 ;;
        --base-dir|-d)     BASE_DIR="$2"; shift 2 ;;
        --ffmpeg)          FFMPEG_PATH="$2"; shift 2 ;;
        --ffprobe)         FFPROBE_PATH="$2"; shift 2 ;;
        --product-brief|-p) PRODUCT_BRIEF_PATH="$2"; shift 2 ;;
        --move)            MOVE_MODE=true; shift ;;
        --keep-work)       KEEP_WORK=true; shift ;;
        --frames|-f)       STORYBOARD_FRAMES="$2"; shift 2 ;;
        --threshold|-t)    SCENE_THRESHOLD="$2"; shift 2 ;;
        --strict)          STRICT_CHECK=true; shift ;;
        --help|-h)         usage ;;
        *) die "Unknown argument: $1" ;;
    esac
done

# -- validation ------------------------------------------------------------

[[ -n "$VIDEO_PATH" ]] || die "--video is required"
[[ -n "$SLUG" ]]         || die "--slug is required"
[[ -n "$NAME" ]]         || die "--name is required"

# -- call start-reference-video.sh -----------------------------------------

START_ARGS=(
    --video "$VIDEO_PATH"
    --slug "$SLUG"
    --name "$NAME"
    --frames "$STORYBOARD_FRAMES"
    --threshold "$SCENE_THRESHOLD"
)

[[ -n "$BASE_DIR" ]]           && START_ARGS+=(--base-dir "$BASE_DIR")
[[ -n "$FFMPEG_PATH" ]]        && START_ARGS+=(--ffmpeg "$FFMPEG_PATH")
[[ -n "$FFPROBE_PATH" ]]       && START_ARGS+=(--ffprobe "$FFPROBE_PATH")
[[ -n "$PRODUCT_BRIEF_PATH" ]] && START_ARGS+=(--product-brief "$PRODUCT_BRIEF_PATH")
$MOVE_MODE                     && START_ARGS+=(--move)
$KEEP_WORK                     && START_ARGS+=(--keep-work)

START_JSON=$("${SCRIPT_DIR}/start-reference-video.sh" "${START_ARGS[@]}") || die "start-reference-video.sh failed"

MATERIAL_DIR=$(echo "$START_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin)['material_folder'])")

# -- check results ---------------------------------------------------------

CHECK_ARGS=(--material-dir "$MATERIAL_DIR" --json)
$STRICT_CHECK && CHECK_ARGS+=(--strict)
CHECK_JSON=$("${SCRIPT_DIR}/check-creative-material.sh" "${CHECK_ARGS[@]}") 2>/dev/null || true

CHECK_STATUS=$(echo "$CHECK_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "unknown")
CHECK_ERRORS=$(echo "$CHECK_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('errors',0))" 2>/dev/null || echo "0")
CHECK_WARNINGS=$(echo "$CHECK_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('warnings',0))" 2>/dev/null || echo "0")

# -- output ----------------------------------------------------------------

python3 -c "
import json
r = json.loads('''$START_JSON''')
r['check_status'] = '$CHECK_STATUS'
r['check_errors'] = $CHECK_ERRORS
r['check_warnings'] = $CHECK_WARNINGS
r['next_step'] = 'AI reads _system-review-系统复查资料/ai-input-pack.md, product-brief-产品信息.md, and the keyframe contact sheet, then replaces the output skeleton documents. If product brief is incomplete, product mapping stays pending.'
print(json.dumps(r, indent=2, ensure_ascii=False))
"

echo ""
echo "=== NEXT STEP ==="
echo "Material folder: $MATERIAL_DIR"
echo ""
echo "AI should now:"
echo "  1. Read _system-review-系统复查资料/ai-input-pack.md"
echo "  2. Open the keyframe contact sheet: $(basename "$MATERIAL_DIR")/keyframes-reference-storyboard-contact-sheet-${NAME}.jpg"
echo "  3. Read _system-review-系统复查资料/frame-index.json"
echo "  4. Fill outputs/reference-video-storyboard-原视频场景变化分镜.md"
echo "  5. Fill outputs/creative-script-directions-创意脚本方向.md"
echo "  6. Fill product-brief-产品信息.md if needed"
