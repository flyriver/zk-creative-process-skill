---
name: zk-creative-process-macos
description: >
  Game ad reference video creative analysis — macOS/Linux/WorkBuddy port.
  Processes reference videos into structured creative-analysis folders with
  keyframe contact sheets, metadata, and AI-ready skeleton documents.
  Supports single (one video) and mix (multi-video same-direction batch) modes.
  Use when the user wants to deconstruct competitor ad videos, analyze hooks,
  map reference structures to their own product, or build story-direction pools.
agent_created: true
---
# ZK Creative Process (macOS/WorkBuddy)

Process game-ad reference videos into clean, reviewable creative-analysis folders.
Code-first: scripts handle deterministic file operations, AI handles creative analysis.

**Command modes:**
- **single**: one reference video → one material folder
- **mix**: multiple same-direction reference videos → one direction-level folder

## Routing

- Use `single` when the user gives one reference video, or doesn't explicitly say videos share a direction.
- Use `mix` when the user says multiple videos are one direction, one hook type, one batch.
- If ambiguous, default to `single`.

## Hard Rules

1. **Scripts first, AI second.** Always run the bash script before writing any analysis.
2. **Copy by default.** Source videos stay put. Use `--move` only when explicitly asked.
3. **Human sees root, AI uses `_system-review-系统复查资料/`.**
4. **Product mapping needs real product info.** If `product-brief-产品信息.md` still has TODO, do NOT invent product facts. List missing questions, mark mapping as pending.
5. **First stage = direction pool.** Do NOT create production storyboards or prompts until the user selects a direction.
6. **Conclusion first, details second.** Keep outputs human-readable.

## single Workflow

Run from the repo root:

```bash
./scripts/process-reference-video-phase1.sh \
  --video "/path/to/reference.mp4" \
  --slug "short-slug" \
  --name "english-name-中文说明" \
  --base-dir "./creative-materials"
```

Optional: `--product-brief /path/to/brief.md`, `--move`, `--frames N`, `--threshold 0.23`, `--keep-work`, `--strict`

After the script runs, **as AI, read these files immediately:**
1. `<material_dir>/_system-review-系统复查资料/ai-input-pack.md` — overview of all paths and rules
2. `<material_dir>/_system-review-系统复查资料/frame-index.json` — frame timestamps and contact sheet positions
3. `<material_dir>/_system-review-系统复查资料/video_metadata.json` — video codec, resolution, duration
4. `<material_dir>/keyframes-reference-storyboard-contact-sheet-*.jpg` — visual keyframe grid (use Read tool to view)
5. `<material_dir>/product-brief-产品信息.md` — product context (fill if the user provides info)

**Then fill these skeleton files:**
- `outputs/reference-video-storyboard-原视频场景变化分镜.md` — scene-by-scene deconstruction
- `outputs/creative-script-directions-创意脚本方向.md` — story-direction pool (NOT production scripts)

## mix Workflow

```bash
./scripts/process-reference-videos-mix.sh \
  --videos "/path/to/vid1.mp4,/path/to/vid2.mp4,/path/to/vid3.mp4" \
  --slug "shared-direction" \
  --name "shared-direction-同方向说明" \
  --base-dir "./creative-materials"
```

After the script runs, read the same system files as single mode, then fill:
- `brief.md` — list all videos, shared theme, differences, transferable structure
- `product-brief-产品信息.md` — product context
- `outputs/shared-analysis-同方向素材共性拆解.md` — shared hook/differences/transferable structure/direction pool

## Analysis Requirements

For both modes, analyze:
- Scene progression (frame by frame from contact sheet)
- Opening hook (first 3 seconds)
- Conflict and pressure mechanism
- Visual language and edit rhythm
- BGM, SFX, voice, captions (when detectable from metadata)
- Transferable structure vs surface style
- Bridge into actual gameplay or product value

Each story direction must include:
- core hypothesis, hook, story premise, conflict/trigger
- product bridge (how to connect to user's product)
- product mapping fit + missing info checklist
- scalable variants, metrics to test, risks, human decision questions

## Completion Checklist

Before ending your response, confirm:
- [ ] Mode used: `single` or `mix`
- [ ] Script ran before AI analysis
- [ ] Material folder path provided
- [ ] `_system-review-系统复查资料/` contains metadata, frame index, manifest, AI input pack
- [ ] Root contains reference video, contact sheet, brief, product brief, outputs/
- [ ] Product mapping status: complete or pending (with missing questions listed)
- [ ] No production folder created before direction selection
