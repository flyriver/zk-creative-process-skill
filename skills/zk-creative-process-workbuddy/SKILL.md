---
name: zk-creative-process
description: >
  Process game-ad reference videos into structured creative-analysis folders
  with keyframe contact sheets, metadata, and AI-ready skeleton documents.
  Supports `single` (one reference video) and `mix` (multiple same-direction
  reference videos batched into one folder) modes. Use when the user asks to
  deconstruct competitor or reference ad videos, analyze opening hooks, build
  story-direction pools, generate keyframe contact sheets, create
  product-brief-产品信息.md, or map a reference video's structure into the
  user's own product. Trigger on phrases like "process this reference video",
  "$zk-creative-process", "single mode", "mix mode", "creative
  materials", "reference deconstruction", or when a video file is provided
  alongside a request for hook/structure/direction analysis.
---

# ZK Creative Process

Process game-ad reference videos into clean, reviewable creative-analysis folders.
Code-first: bash scripts handle deterministic file operations, the agent handles creative analysis.

## Modes

- **single**: one reference video → one material folder
- **mix**: multiple same-direction reference videos → one direction-level folder

### Routing

- Use `single` when the user provides one reference video, or doesn't explicitly say multiple videos share a direction.
- Use `mix` when the user says multiple videos are one direction, one hook type, or should be analyzed together.
- If ambiguous, default to `single`.

## Hard Rules

1. **Scripts first, AI second.** Always run the bash script before writing any analysis.
2. **Copy by default.** Source videos stay put. Use `--move` only when the user explicitly asks.
3. **Human sees root, AI uses `_system-review-系统复查资料/`.** Keep human-facing files in the material root and automation files in `_system-review-系统复查资料/`.
4. **Product mapping needs real product info.** If `product-brief-产品信息.md` still has `TODO`, do NOT invent product facts. List missing questions and mark mapping as pending.
5. **First stage = direction pool.** Do NOT create production storyboards or prompts until the user selects a specific direction.
6. **Conclusion first, details second.** Keep outputs human-readable.

## Prerequisites

The scripts require `ffmpeg` and `ffprobe` on `PATH`:

```bash
brew install ffmpeg
```

Verify with `bash ~/.workbuddy/skills/zk-creative-process/scripts/check-environment.sh`.

## Single Workflow

Run the bundled script. Prefer the installed skill's `scripts/` directory; if working inside the cloned repository, the repo-root `scripts/` folder is equivalent.

```bash
bash ~/.workbuddy/skills/zk-creative-process/scripts/process-reference-video-phase1.sh \
  --video "/path/to/reference.mp4" \
  --slug "short-slug" \
  --name "english-name-中文说明" \
  --base-dir "./creative-materials"
```

Optional flags: `--product-brief /path/to/brief.md`, `--move`, `--frames N` (default 12), `--threshold 0.23`, `--keep-work`, `--strict`.

After the script runs, **read these files immediately** (use the `Read` tool):

1. `<material_dir>/_system-review-系统复查资料/ai-input-pack.md` — overview of all paths and rules
2. `<material_dir>/_system-review-系统复查资料/frame-index.json` — frame timestamps and contact sheet positions
3. `<material_dir>/_system-review-系统复查资料/video_metadata.json` — codec, resolution, duration
4. `<material_dir>/keyframes-reference-storyboard-contact-sheet-*.jpg` — visual keyframe grid
5. `<material_dir>/product-brief-产品信息.md` — product context (fill if the user provided info)

**Then fill these skeleton files:**

- `outputs/reference-video-storyboard-原视频场景变化分镜.md` — scene-by-scene deconstruction
- `outputs/creative-script-directions-创意脚本方向.md` — story-direction pool (NOT production scripts)

## Mix Workflow

```bash
bash ~/.workbuddy/skills/zk-creative-process/scripts/process-reference-videos-mix.sh \
  --videos "/path/to/vid1.mp4,/path/to/vid2.mp4,/path/to/vid3.mp4" \
  --slug "shared-direction" \
  --name "shared-direction-同方向说明" \
  --base-dir "./creative-materials"
```

Mix mode defaults to `--frames 8` per video. After the script runs, read the same system files as single mode, then fill:

- `brief.md` — list all videos, shared theme, differences, transferable structure, unified test goal
- `product-brief-产品信息.md` — product context
- `outputs/shared-analysis-同方向素材共性拆解.md` — shared hook, differences, transferable structure, direction pool

## Analysis Requirements

For both modes, analyze:

- Scene progression (frame by frame from the contact sheet)
- Opening hook (first 3 seconds)
- Conflict and pressure mechanism
- Visual language and edit rhythm
- BGM, SFX, voice, captions (when detectable from metadata)
- Transferable structure vs surface style
- Bridge into actual gameplay or product value

Each story direction must include:

- core hypothesis, hook, story premise, conflict/trigger
- product bridge (how to connect to the user's product)
- product mapping fit + missing-info checklist
- scalable variants, metrics to test, risks, human decision questions

## Completion Checklist

Before ending the response, confirm:

- [ ] Mode used: `single` or `mix`
- [ ] Script ran before AI analysis
- [ ] Material folder path provided
- [ ] `_system-review-系统复查资料/` contains metadata, frame index, manifest, AI input pack
- [ ] Root contains reference video, contact sheet, brief, product brief, `outputs/`
- [ ] Product mapping status: complete, or pending with missing questions listed
- [ ] No production folder created before a direction was selected

## Troubleshooting

If `ffmpeg`/`ffprobe` are killed inside a sandboxed agent environment, run the scripts from your terminal directly, then ask the agent to read the generated files. See [troubleshooting.md](../../docs/troubleshooting.md) for details (note: this path resolves only when running from the cloned repository; the installed skill is self-contained at `~/.workbuddy/skills/zk-creative-process/`).