# ZK Creative Process (macOS / WorkBuddy)

Process game-ad reference videos into structured creative-analysis folders.
**Scripts handle file operations — AI handles creative analysis.**

```text
reference video → keyframes + metadata → AI reads → storyboard + direction pool
```

## What It Creates

```text
creative-materials/YYYY-MM-DD-slug-name/
  original-name.mp4                                      # copied reference video
  keyframes-reference-storyboard-contact-sheet-name.jpg  # visual keyframe grid
  brief.md                                               # AI-filled summary (mix mode)
  product-brief-产品信息.md                               # product context (you fill)
  outputs/
    reference-video-storyboard-原视频场景变化分镜.md       # scene-by-scene deconstruction
    creative-script-directions-创意脚本方向.md             # direction pool (NOT finals)
  _system-review-系统复查资料/
    ai-input-pack.md                                     # AI reads this first
    frame-index.json                                     # frame timestamps
    run-manifest.json
    video_metadata.json
```

> **`product-brief-产品信息.md`** is the bridge from reference analysis to your product.
> If it still contains `TODO`, the AI will not invent product facts — mapping stays pending.

## Prerequisites

```bash
brew install ffmpeg
```

Then verify:

```bash
./scripts/check-environment.sh
```

## Install the Skill

Run the installer from this repository root. It copies both the skill definition and the bash scripts it needs at runtime:

```bash
bash scripts/install-workbuddy-skill.sh
```

If the skill already exists, choose explicitly:

```bash
bash scripts/install-workbuddy-skill.sh --backup
bash scripts/install-workbuddy-skill.sh --force
```

The skill is now available in WorkBuddy with its bundled scripts under `~/.workbuddy/skills/zk-creative-process-macos/scripts/`.

## Usage

### Single video

One reference video → one material folder.

```bash
./scripts/process-reference-video-phase1.sh \
  --video "/path/to/reference.mp4" \
  --slug "short-slug" \
  --name "English-Name-中文说明" \
  --base-dir "./creative-materials"
```

Available options:

| Flag | Default | Description |
|------|---------|-------------|
| `--product-brief` | (none) | Pre-filled product context markdown |
| `--frames` | 12 | Storyboard frames to extract for single mode |
| `--threshold` | 0.23 | Scene-change sensitivity (lower = more frames) |
| `--move` | off | Move source video instead of copying |
| `--keep-work` | off | Keep intermediate extraction folder |
| `--strict` | off | Fail on warnings instead of continuing |

### Mix mode (batch)

Multiple same-direction videos → one direction-level folder.

```bash
./scripts/process-reference-videos-mix.sh \
  --videos "/path/to/vid1.mp4,/path/to/vid2.mp4,/path/to/vid3.mp4" \
  --slug "shared-direction" \
  --name "Shared-Direction-同方向说明" \
  --base-dir "./creative-materials"
```

Mix mode uses `--frames 8` by default, per video.

## After the Script Runs

The script produces a complete folder with keyframes, metadata, and AI-ready skeleton files.
**Then let WorkBuddy (or any AI assistant) read the generated files:**

1. `_system-review-系统复查资料/ai-input-pack.md` — overview of all paths and rules
2. `_system-review-系统复查资料/frame-index.json` — frame timestamps
3. `_system-review-系统复查资料/video_metadata.json` — codec, resolution, duration
4. `keyframes-reference-storyboard-contact-sheet-*.jpg` — visual keyframe grid
5. `product-brief-产品信息.md` — fill this with your product context first

The AI will then fill:

| Mode | Files filled |
|------|-------------|
| single | `outputs/reference-video-storyboard-原视频场景变化分镜.md` + `outputs/creative-script-directions-创意脚本方向.md` |
| mix | `brief.md` + `outputs/shared-analysis-同方向素材共性拆解.md` |

### What the AI analyzes

- Scene progression (frame by frame from the contact sheet)
- Opening hook (first 3 seconds)
- Conflict and pressure mechanism
- Visual language and edit rhythm
- BGM, SFX, voice, captions (when detectable from metadata)
- Transferable structure vs surface style
- Bridge into actual gameplay or product value

Each story direction includes: core hypothesis, hook, story premise, product bridge, fit assessment, missing-info checklist, scalable variants, and human decision questions.

> **Important:** The first stage is a direction pool. Do NOT create production storyboards until a direction is selected.
> If running inside a WorkBuddy sandbox, ffmpeg/ffprobe may be blocked.
> Run the scripts in your terminal first, then ask the AI to read the generated files.
> See [troubleshooting](docs/troubleshooting.md) for details.

## Windows / Codex

This branch (`workbuddy-macos-port`) targets macOS and Linux with bash scripts.
For the Windows/PowerShell + Codex version, switch to:

```bash
git checkout main
```

The `main` branch includes `.ps1` scripts and `skills/zk-creative-process/` for Codex on Windows.

## Validate Generated Material

```bash
./scripts/check-creative-material.sh --material-dir ./creative-materials/YYYY-MM-DD-slug-name
```

## Privacy

- Do not commit customer videos, competitor videos, ad data, product strategy, filled product briefs, or generated `creative-materials/`.
- `.gitignore` ignores common video formats and generated folders (except the bundled sample `shower.mp4`).
- Scripts are generic and do not depend on any private project folder.

## Docs

- [Creative process guide](docs/creative-process-guide.md)
- [Folder structure](docs/example-folder-structure.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Single example](examples/single/README.md)
- [Mix example](examples/mix/README.md)
