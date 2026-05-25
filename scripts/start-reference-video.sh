#!/usr/bin/env bash
#
# start-reference-video.sh — Core engine for reference video processing (macOS/Linux port)
#
# Extracts keyframes, generates contact sheets, metadata, and skeleton markdown files
# for a single reference video. Called by process-reference-video-phase1.sh.
#
# Dependencies: ffmpeg, ffprobe

set -euo pipefail

# -- helpers ---------------------------------------------------------------

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "[$(date '+%H:%M:%S')] $*" >&2; }

assert_safe_filename_part() {
    local value="$1"
    local field_name="$2"
    [[ -n "$value" ]] || die "${field_name} cannot be empty"
    if [[ "$value" =~ [\\/:*?\<\>\|\"] ]]; then
        die "${field_name} contains invalid filename characters: $value"
    fi
}

parse_fps() {
    local rate="$1"
    if [[ "$rate" == *"/"* ]]; then
        local num den
        num=$(echo "$rate" | cut -d/ -f1)
        den=$(echo "$rate" | cut -d/ -f2)
        if [[ "$den" != "0" ]]; then
            python3 -c "print(round($num / $den, 4))"
            return
        fi
    fi
    echo ""
}

# -- argument parsing ------------------------------------------------------

VIDEO_PATH=""
SLUG=""
NAME=""
BASE_DIR=""
FFMPEG_PATH="ffmpeg"
FFPROBE_PATH="ffprobe"
PRODUCT_BRIEF_PATH=""
MOVE_MODE=false
KEEP_WORK=false
STORYBOARD_FRAMES=12
SCENE_THRESHOLD=0.23

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
        *) die "Unknown argument: $1" ;;
    esac
done

# -- validation ------------------------------------------------------------

[[ -n "$VIDEO_PATH" ]]   || die "--video is required"
[[ -n "$SLUG" ]]         || die "--slug is required"
[[ -n "$NAME" ]]         || die "--name is required"

# Validate slug: lowercase alphanumeric + hyphens only
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

# Resolve source video
SOURCE_VIDEO=$(realpath "$VIDEO_PATH" 2>/dev/null || readlink -f "$VIDEO_PATH" 2>/dev/null || echo "$VIDEO_PATH")
[[ -f "$SOURCE_VIDEO" ]] || die "Video file not found: $VIDEO_PATH"

# Determine base dir
if [[ -z "$BASE_DIR" ]]; then
    BASE_DIR="$(pwd)/creative-materials"
fi
mkdir -p "$BASE_DIR"
BASE_DIR=$(cd "$BASE_DIR" && pwd)

# -- file/path setup -------------------------------------------------------

EXT="${SOURCE_VIDEO##*.}"
[[ -z "$EXT" || "$EXT" == "$SOURCE_VIDEO" ]] && EXT="mp4"
DATE_PREFIX=$(date +%Y-%m-%d)
MATERIAL_NAME="${DATE_PREFIX}-${SLUG}-${NAME}"
MATERIAL_DIR="${BASE_DIR}/${MATERIAL_NAME}"

if [[ -d "$MATERIAL_DIR" ]]; then
    die "Material folder already exists: $MATERIAL_DIR"
fi

OUTPUTS_DIR="${MATERIAL_DIR}/outputs"
SYSTEM_DIR="${MATERIAL_DIR}/_system-review-系统复查资料"
WORK_DIR="${MATERIAL_DIR}/keyframes-work"

mkdir -p "$MATERIAL_DIR" "$OUTPUTS_DIR" "$SYSTEM_DIR"

# -- copy/move source video ------------------------------------------------

DEST_VIDEO="${MATERIAL_DIR}/original-${NAME}.${EXT}"
if $MOVE_MODE; then
    mv "$SOURCE_VIDEO" "$DEST_VIDEO"
    VIDEO_ACTION="moved"
else
    cp "$SOURCE_VIDEO" "$DEST_VIDEO"
    VIDEO_ACTION="copied"
fi

log "Video $VIDEO_ACTION to $DEST_VIDEO"

# -- product brief ---------------------------------------------------------

PRODUCT_BRIEF_OUT="${MATERIAL_DIR}/product-brief-产品信息.md"
if [[ -n "$PRODUCT_BRIEF_PATH" ]]; then
    [[ -f "$PRODUCT_BRIEF_PATH" ]] || die "Product brief not found: $PRODUCT_BRIEF_PATH"
    cp "$PRODUCT_BRIEF_PATH" "$PRODUCT_BRIEF_OUT"
else
    cat > "$PRODUCT_BRIEF_OUT" << 'PRODUCTBRIEF'
# Product Brief

Fill this before asking AI to map the reference video into your own product.

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
- Mechanics that can connect to the reference hook: TODO
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

# -- probe video metadata --------------------------------------------------

log "Probing video metadata..."
PROBE_JSON=$("$FFPROBE" -v error -print_format json -show_streams -show_format "$DEST_VIDEO" 2>/dev/null) || die "ffprobe failed"

# Extract video stream info
VIDEO_CODEC=$(echo "$PROBE_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
vs=[s for s in d['streams'] if s['codec_type']=='video']
if not vs: sys.exit(1)
v=vs[0]
print(v.get('codec_name',''))
")
[[ -n "$VIDEO_CODEC" ]] || die "No video stream found"

VIDEO_WIDTH=$(echo "$PROBE_JSON" | python3 -c "
import json,sys
v=[s for s in json.load(sys.stdin)['streams'] if s['codec_type']=='video'][0]
print(v.get('width',0))
")
VIDEO_HEIGHT=$(echo "$PROBE_JSON" | python3 -c "
import json,sys
v=[s for s in json.load(sys.stdin)['streams'] if s['codec_type']=='video'][0]
print(v.get('height',0))
")
R_FRAME_RATE=$(echo "$PROBE_JSON" | python3 -c "
import json,sys
v=[s for s in json.load(sys.stdin)['streams'] if s['codec_type']=='video'][0]
print(v.get('r_frame_rate',''))
")
FPS=$(parse_fps "$R_FRAME_RATE")
DURATION=$(echo "$PROBE_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
vs=[s for s in d['streams'] if s['codec_type']=='video']
dur=float(vs[0].get('duration',0) if vs else 0)
if dur==0: dur=float(d.get('format',{}).get('duration',0))
print(round(dur,3))
")
[[ "$DURATION" != "0" && "$DURATION" != "0.0" ]] || die "Cannot determine video duration"

# Audio stream
HAS_AUDIO=false
AUDIO_CODEC=""
AUDIO_DURATION=""
if echo "$PROBE_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(len([s for s in d['streams'] if s['codec_type']=='audio']))
" 2>/dev/null | grep -qv '^0$'; then
    HAS_AUDIO=true
    AUDIO_CODEC=$(echo "$PROBE_JSON" | python3 -c "
import json,sys
al=[s for s in json.load(sys.stdin)['streams'] if s['codec_type']=='audio']
print(al[0].get('codec_name','') if al else '')
")
    AUDIO_DURATION=$(echo "$PROBE_JSON" | python3 -c "
import json,sys
al=[s for s in json.load(sys.stdin)['streams'] if s['codec_type']=='audio']
d=al[0].get('duration','') if al else ''
print(round(float(d),3) if d else '')
")
fi

# Format info
FORMAT_DURATION=$(echo "$PROBE_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin).get('format',{})
print(round(float(d.get('duration',0)),3))
")
FORMAT_SIZE=$(echo "$PROBE_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin).get('format',{})
print(d.get('size',''))
")
FORMAT_BITRATE=$(echo "$PROBE_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin).get('format',{})
print(d.get('bit_rate',''))
")

# Write metadata JSON
METADATA_PATH="${SYSTEM_DIR}/video_metadata.json"
NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%S)
python3 - "$METADATA_PATH" "$NOW_ISO" "$VIDEO_ACTION" "$MATERIAL_DIR" "$(basename "$DEST_VIDEO")" \
    "$VIDEO_CODEC" "$VIDEO_WIDTH" "$VIDEO_HEIGHT" "$R_FRAME_RATE" "${FPS:-}" "$DURATION" \
    "$HAS_AUDIO" "$AUDIO_CODEC" "${AUDIO_DURATION:-}" "$FORMAT_DURATION" "${FORMAT_SIZE:-}" "${FORMAT_BITRATE:-}" <<'PY'
import json
import sys

def optional_float(value):
    return float(value) if value else None

def optional_int(value):
    return int(value) if value else None

(
    output_path,
    generated_at,
    source_video_action,
    material_folder,
    file_name,
    video_codec,
    video_width,
    video_height,
    r_frame_rate,
    fps,
    duration,
    has_audio,
    audio_codec,
    audio_duration,
    format_duration,
    format_size,
    format_bitrate,
) = sys.argv[1:]

meta = {
    "generated_at": generated_at,
    "source_video_action": source_video_action,
    "material_folder": material_folder,
    "file": file_name,
    "video": {
        "codec": video_codec,
        "width": int(video_width),
        "height": int(video_height),
        "r_frame_rate": r_frame_rate,
        "fps": optional_float(fps),
        "duration_seconds": float(duration),
        "nb_frames": None,
    },
    "audio": {
        "codec": audio_codec,
        "duration_seconds": optional_float(audio_duration),
    } if has_audio == "true" else None,
    "format": {
        "duration_seconds": optional_float(format_duration),
        "size_bytes": optional_int(format_size),
        "bit_rate": optional_int(format_bitrate),
    },
}
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(meta, f, indent=2, ensure_ascii=False)
PY

# -- keyframe extraction ---------------------------------------------------

log "Extracting keyframes..."
UNIFORM_DIR="${WORK_DIR}/uniform"
SCENE_DIR="${WORK_DIR}/scene"
SELECTED_DIR="${WORK_DIR}/selected"
mkdir -p "$UNIFORM_DIR" "$SCENE_DIR" "$SELECTED_DIR"

# Uniform frames: 1 per second, scaled to 360 width
log "  Extracting uniform frames..."
"$FFMPEG" -hide_banner -y -i "$DEST_VIDEO" \
    -vf 'fps=1,scale=360:-1' \
    "${UNIFORM_DIR}/uniform-%03d.jpg" \
    > "${WORK_DIR}/ffmpeg-uniform.log" 2>&1 || die "Uniform frame extraction failed"

# Scene change frames
log "  Detecting scene changes..."
"$FFMPEG" -hide_banner -y -i "$DEST_VIDEO" \
    -vf "select='gt(scene,${SCENE_THRESHOLD})',scale=360:-1" \
    -vsync vfr \
    "${SCENE_DIR}/scene-%03d.jpg" \
    > "${WORK_DIR}/ffmpeg-scene.log" 2>&1 || log "  (scene detection completed with warnings)"

# Selected frames: uniformly spaced timestamps
log "  Extracting ${STORYBOARD_FRAMES} selected frames..."
START_TIME=0.03
END_TIME=$(python3 -c "print(max(0.03, $DURATION - 0.35))")
SELECTED_FRAMES_JSON="["

for i in $(seq 0 $((STORYBOARD_FRAMES - 1))); do
    idx=$((i + 1))
    if [[ $STORYBOARD_FRAMES -eq 1 ]]; then
        ratio=0
    else
        ratio=$(python3 -c "print($i / ($STORYBOARD_FRAMES - 1))")
    fi
    timestamp=$(python3 -c "print(round($START_TIME + ($END_TIME - $START_TIME) * $ratio, 3))")
    fname=$(printf "selected-%02d.jpg" "$idx")
    row=$((i / 4 + 1))
    col=$((i % 4 + 1))

    "$FFMPEG" -hide_banner -y \
        -ss "$timestamp" -i "$DEST_VIDEO" \
        -frames:v 1 -q:v 2 \
        -vf 'scale=360:-1' \
        -update 1 \
        "${SELECTED_DIR}/${fname}" \
        > "${WORK_DIR}/ffmpeg-selected-$(printf '%02d' "$idx").log" 2>&1 \
        || die "Frame $idx extraction failed at ${timestamp}s"

    if [[ $i -gt 0 ]]; then
        SELECTED_FRAMES_JSON+=","
    fi
    SELECTED_FRAMES_JSON+="{\"index\":$idx,\"timestamp_seconds\":$timestamp,\"work_file\":\"$fname\",\"contact_sheet_position\":{\"row\":$row,\"column\":$col},\"ai_instruction\":\"Use contact sheet frame $idx at approximately ${timestamp}s.\"}"
done
SELECTED_FRAMES_JSON+="]"

# Write frame-index.json
FRAME_INDEX_PATH="${SYSTEM_DIR}/frame-index.json"
FINAL_SHEET_NAME="keyframes-reference-storyboard-contact-sheet-${NAME}.jpg"
python3 - "$FRAME_INDEX_PATH" "$NOW_ISO" "$(basename "$DEST_VIDEO")" "$FINAL_SHEET_NAME" "$STORYBOARD_FRAMES" "$SELECTED_FRAMES_JSON" <<'PY'
import json
import sys

output_path, generated_at, source_video, contact_sheet, frame_count, frames_json = sys.argv[1:]
idx = {
    "generated_at": generated_at,
    "source_video": source_video,
    "contact_sheet": contact_sheet,
    "frame_count": int(frame_count),
    "selection_method": "uniform timestamps across source duration",
    "frames": json.loads(frames_json),
}
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(idx, f, indent=2, ensure_ascii=False)
PY

# -- contact sheet (tile) generation ---------------------------------------

log "Generating contact sheet..."
FINAL_SHEET="${MATERIAL_DIR}/${FINAL_SHEET_NAME}"
ROWS=$(python3 -c "import math; print(math.ceil($STORYBOARD_FRAMES / 4))")

"$FFMPEG" -hide_banner -y \
    -framerate 1 \
    -i "${SELECTED_DIR}/selected-%02d.jpg" \
    -vf "tile=4x${ROWS}:padding=4:margin=2" \
    -frames:v 1 \
    "$FINAL_SHEET" \
    > "${WORK_DIR}/ffmpeg-final-sheet.log" 2>&1 \
    || die "Contact sheet generation failed"

# -- skeleton markdown files -----------------------------------------------

log "Writing skeleton files..."

# brief.md
cat > "${MATERIAL_DIR}/brief.md" << BRIEF
# ${NAME} Reference Video Creative Task

## Source Video

- File: [original-${NAME}.${EXT}](original-${NAME}.${EXT})
- Video: ${DURATION} seconds, ${VIDEO_WIDTH}x${VIDEO_HEIGHT}, ${FPS:-N/A}fps.
- Metadata: [_system-review-系统复查资料/video_metadata.json](_system-review-系统复查资料/video_metadata.json)

## Generated Assets

- Keyframe contact sheet: [${FINAL_SHEET_NAME}](${FINAL_SHEET_NAME})
- Output folder: [outputs](outputs/)
- Product brief: [product-brief-产品信息.md](product-brief-产品信息.md)

## Product Context

Fill \`product-brief-产品信息.md\` before mapping the reference structure into your own product.

## AI Output Requirements

- Fill \`outputs/reference-video-storyboard-原视频场景变化分镜.md\`.
- Fill \`outputs/creative-script-directions-创意脚本方向.md\`.
- First produce a story-direction pool only.
- Do not create production storyboard or prompt folders until a direction is selected.
BRIEF

# reference-video-storyboard
REFERENCE_PATH="${OUTPUTS_DIR}/reference-video-storyboard-原视频场景变化分镜.md"
cat > "$REFERENCE_PATH" << 'STORYBOARD'
# Reference Video Storyboard

## Keyframe And Metadata

- Keyframe contact sheet: [keyframes-reference-storyboard-contact-sheet-*.jpg](../keyframes-reference-storyboard-contact-sheet-*.jpg)
- Metadata: [video_metadata.json](../_system-review-系统复查资料/video_metadata.json)

## Scene Progression

| Order | Representative frame | Scene content | Information progress | Transferable structure |
| --- | --- | --- | --- | --- |
| 1 | TODO | TODO | TODO | TODO |

## Underlying Structure

TODO

## Transfer Notes

TODO

## Do Not Copy Directly

TODO
STORYBOARD

# creative-script-directions
DIRECTIONS_PATH="${OUTPUTS_DIR}/creative-script-directions-创意脚本方向.md"
cat > "$DIRECTIONS_PATH" << 'DIRECTIONS'
# Creative Script Directions

## Assumptions

TODO

## Direction Overview

| Direction | Core hook | User desire | What to test | Risk |
| --- | --- | --- | --- | --- |
| 1 | TODO | TODO | TODO | TODO |

## Direction 1

### Core Hypothesis

TODO

### Hook

TODO

### Story Premise

TODO

### Conflict And Trigger

TODO

### Product Bridge

TODO

### Product Mapping

Use `../product-brief-产品信息.md`. If it still contains TODO or lacks product-specific information, list missing questions and mark product mapping as pending.

### Scalable Variants

TODO

### Metrics To Test

TODO

### Human Decision Questions

TODO
DIRECTIONS

# ai-input-pack
AI_INPUT_PACK="${SYSTEM_DIR}/ai-input-pack.md"
cat > "$AI_INPUT_PACK" << AIPACK
# AI Input Pack: ${NAME}

Read this file first, then inspect the keyframe contact sheet and frame-index.

## Paths

- Material folder: ${MATERIAL_DIR}
- Source video: ${DEST_VIDEO}
- Keyframe contact sheet: ${FINAL_SHEET}
- Frame index: ${FRAME_INDEX_PATH}
- Reference storyboard: ${REFERENCE_PATH}
- Creative directions: ${DIRECTIONS_PATH}
- Product brief: ${PRODUCT_BRIEF_OUT}

## Video

- Duration: ${DURATION} seconds
- Size: ${VIDEO_WIDTH}x${VIDEO_HEIGHT}
- FPS: ${FPS:-N/A}
- Selected frames: ${STORYBOARD_FRAMES}

## First Stage Rules

- Fill reference-video-storyboard-原视频场景变化分镜.md.
- Fill creative-script-directions-创意脚本方向.md.
- Use product-brief-产品信息.md for product mapping.
- If product-brief-产品信息.md still contains TODO or lacks product-specific information, do not invent product facts. Output the missing questions and keep product mapping marked as pending.
- Only create a story-direction pool.
- Do not create production scripts or prompts until the user selects a direction.
AIPACK

# run-manifest.json
MANIFEST_PATH="${SYSTEM_DIR}/run-manifest.json"
UNIFORM_COUNT=$(find "$UNIFORM_DIR" -name '*.jpg' 2>/dev/null | wc -l | tr -d ' ')
SCENE_COUNT=$(find "$SCENE_DIR" -name '*.jpg' 2>/dev/null | wc -l | tr -d ' ')
python3 - "$MANIFEST_PATH" "$NOW_ISO" "$MATERIAL_DIR" "$DEST_VIDEO" "$METADATA_PATH" "$FRAME_INDEX_PATH" \
    "$FINAL_SHEET" "$AI_INPUT_PACK" "${MATERIAL_DIR}/brief.md" "$PRODUCT_BRIEF_OUT" "$REFERENCE_PATH" \
    "$DIRECTIONS_PATH" "$KEEP_WORK" "$STORYBOARD_FRAMES" "${UNIFORM_COUNT:-0}" "${SCENE_COUNT:-0}" <<'PY'
import json
import sys

(
    output_path,
    generated_at,
    material_folder,
    video,
    metadata,
    frame_index,
    final_storyboard_sheet,
    ai_input_pack,
    brief,
    product_brief,
    reference_path,
    directions_path,
    keep_work,
    selected_count,
    uniform_count,
    scene_count,
) = sys.argv[1:]

m = {
    "generated_at": generated_at,
    "script": "start-reference-video.sh",
    "material_folder": material_folder,
    "video": video,
    "metadata": metadata,
    "frame_index": frame_index,
    "final_storyboard_sheet": final_storyboard_sheet,
    "ai_input_pack": ai_input_pack,
    "brief": brief,
    "product_brief": product_brief,
    "outputs": [reference_path, directions_path],
    "temp_work_dir_kept": keep_work == "true",
    "frame_counts": {
        "selected": int(selected_count),
        "uniform": int(uniform_count),
        "scene": int(scene_count),
    },
    "next_ai_inputs": [
        "Read _system-review-系统复查资料/ai-input-pack.md.",
        "Open final_storyboard_sheet once.",
        "Use _system-review-系统复查资料/frame-index.json for timestamp and contact-sheet positions.",
        "Replace skeleton text in outputs with AI analysis.",
    ],
}
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(m, f, indent=2, ensure_ascii=False)
PY

# -- cleanup ---------------------------------------------------------------

if ! $KEEP_WORK; then
    rm -rf "$WORK_DIR"
    log "Cleaned up work directory"
fi

# -- output JSON result ----------------------------------------------------

log "Done. Material folder: $MATERIAL_DIR"

python3 - "$MATERIAL_DIR" "$AI_INPUT_PACK" "$FINAL_SHEET" "$FRAME_INDEX_PATH" "${MATERIAL_DIR}/brief.md" \
    "$PRODUCT_BRIEF_OUT" "$REFERENCE_PATH" "$DIRECTIONS_PATH" "$MANIFEST_PATH" <<'PY'
import json
import sys

(
    material_folder,
    ai_input_pack,
    final_storyboard_sheet,
    frame_index,
    brief,
    product_brief,
    reference_storyboard,
    creative_directions,
    manifest,
) = sys.argv[1:]

result = {
    "material_folder": material_folder,
    "ai_input_pack": ai_input_pack,
    "final_storyboard_sheet": final_storyboard_sheet,
    "frame_index": frame_index,
    "brief": brief,
    "product_brief": product_brief,
    "reference_storyboard": reference_storyboard,
    "creative_directions": creative_directions,
    "manifest": manifest,
}
print(json.dumps(result, indent=2, ensure_ascii=False))
PY
