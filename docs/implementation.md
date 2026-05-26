# Skill Implementation

This document explains how the `zk-creative-process` skill is packaged, installed, and executed.

The repository is deliberately split into two responsibilities:

- agent instructions decide when to use the skill and what the AI should write
- scripts perform deterministic filesystem, video, metadata, keyframe, and validation work

That split is the main design constraint. The skill should not rely on an agent to manually create folders or guess paths before analysis starts.

## Repository Layout

```text
.
  README.md
  AGENTS.md
  docs/
  examples/
  scripts/
  skills/
    zk-creative-process/
    zk-creative-process-cursor/
    zk-creative-process-workbuddy/
```

The important directories are:

- `skills/zk-creative-process/`: Codex skill source. It includes `SKILL.md`, `agents/openai.yaml`, and bundled PowerShell scripts.
- `skills/zk-creative-process-cursor/`: Cursor-facing skill source. It installs as `zk-creative-process`.
- `skills/zk-creative-process-workbuddy/`: WorkBuddy-facing skill source. It installs as `zk-creative-process`.
- `scripts/`: repository-level development and installer entrypoints. These are the canonical macOS bash scripts and also include PowerShell copies.
- `docs/`: longer explanations that should not crowd the README.
- `examples/`: public lightweight examples only.

Generated folders and private media are intentionally ignored by `.gitignore`: `creative-materials/`, common video extensions, `.tmp/`, and `keyframes-work/`.

## Skill Packages

Each agent package exposes the same skill name, `zk-creative-process`, but with agent-specific installation paths and runtime assumptions.

### Codex Package

Path: `skills/zk-creative-process/`

Files:

- `SKILL.md`: the main Codex skill instruction file.
- `agents/openai.yaml`: display metadata for OpenAI-compatible skill surfaces.
- `scripts/*.ps1`: Windows PowerShell runtime scripts bundled directly with the Codex package.

The Codex `SKILL.md` describes:

- `single` mode for one reference video
- `mix` mode for a same-direction batch
- routing rules for ambiguous user requests
- hard rules around copy-by-default, product mapping, and first-stage-only output
- exact script commands for Windows and macOS
- required files the agent must read after scripts run
- completion checks before responding

On macOS, the install script also copies bash runtime scripts into the installed Codex skill directory, even though the repository source package stores PowerShell scripts under `skills/zk-creative-process/scripts/`.

### Cursor Package

Path: `skills/zk-creative-process-cursor/`

This package contains a Cursor-oriented `SKILL.md`. It uses the same workflow and output contract, but paths point to `~/.cursor/skills/zk-creative-process/scripts/`.

The Cursor package is installed from its source directory but receives the repository bash runtime scripts during installation.

### WorkBuddy Package

Path: `skills/zk-creative-process-workbuddy/`

This package mirrors the Cursor package, with paths pointing to `~/.workbuddy/skills/zk-creative-process/scripts/`.

## Installation

There are two installer families:

- `scripts/install-skill.ps1` for Windows Codex installs
- `scripts/install-skill.sh` for macOS Codex, Cursor, and WorkBuddy installs

### macOS Installer

Command shape:

```bash
bash scripts/install-skill.sh --agent codex
bash scripts/install-skill.sh --agent cursor
bash scripts/install-skill.sh --agent workbuddy
```

The installer:

1. Requires `--agent`.
2. Chooses a source skill package:
   - Codex: `skills/zk-creative-process`
   - Cursor: `skills/zk-creative-process-cursor`
   - WorkBuddy: `skills/zk-creative-process-workbuddy`
3. Chooses an install root:
   - Codex: `${CODEX_SKILLS_DIR:-$HOME/.codex/skills}`
   - Cursor: `${CURSOR_SKILLS_DIR:-$HOME/.cursor/skills}`
   - WorkBuddy: `${WORKBUDDY_SKILLS_DIR:-$HOME/.workbuddy/skills}`
4. Copies the selected skill source to `<skills-dir>/zk-creative-process`.
5. Copies these bash runtime scripts from repository `scripts/` into the installed skill's `scripts/` directory:
   - `check-creative-material.sh`
   - `check-environment.sh`
   - `process-reference-video-phase1.sh`
   - `process-reference-videos-mix.sh`
   - `start-reference-video.sh`
6. Makes the copied bash scripts executable.

Existing installs are protected by default. If the destination exists, the installer exits unless the user passes:

- `--backup`: move the old install to `zk-creative-process.backup-YYYYMMDD-HHMMSS`
- `--force`: remove and replace the old install

Cursor has one extra option:

```bash
bash scripts/install-skill.sh --agent cursor --project
```

That installs into `./.cursor/skills/zk-creative-process` under the current directory.

### Windows Installer

Command shape:

```powershell
.\scripts\install-skill.ps1
```

The Windows installer:

1. Resolves the skill source.
2. Defaults to `%USERPROFILE%\.codex\skills`.
3. Copies `skills\zk-creative-process` into `zk-creative-process`.
4. Copies runtime scripts into the installed package.
5. Protects existing installs unless `-Backup` or `-Force` is passed.

It also supports being run from a self-contained installed skill directory, which is why it checks whether its parent already contains `SKILL.md`.

## Runtime Modes

The skill has two runtime modes: `single` and `mix`.

Both modes follow the same high-level sequence:

```text
user request
  -> agent routes to single or mix
  -> script creates material folder
  -> script copies or moves source video
  -> script probes video metadata
  -> script extracts selected frames
  -> script builds contact sheet
  -> script writes skeleton markdown and system files
  -> agent reads generated inputs
  -> agent replaces skeleton output files with analysis
```

Scripts copy source videos by default. Moving originals is only allowed when the user explicitly asks for it:

- PowerShell: `-Move`
- bash: `--move`

## Single Mode

Single mode processes one reference video into one material folder.

Primary orchestrators:

- bash: `scripts/process-reference-video-phase1.sh`
- PowerShell: `scripts/process-reference-video-phase1.ps1`

Core engine:

- bash: `scripts/start-reference-video.sh`
- PowerShell: `scripts/start-reference-video.ps1`

### Input Contract

Required inputs:

- video path
- slug
- name

Important options:

- base output directory, defaulting to `./creative-materials`
- explicit `ffmpeg` and `ffprobe` paths
- product brief path
- copy or move behavior
- whether to keep `keyframes-work/`
- selected storyboard frame count, default `12`
- scene threshold, default `0.23`

The slug must match lowercase alphanumeric plus hyphens:

```text
^[a-z0-9][a-z0-9-]*$
```

The name cannot contain filename-hostile characters such as slashes, colons, quotes, angle brackets, or pipe.

### Folder Contract

Single mode creates:

```text
creative-materials/YYYY-MM-DD-slug-name/
  original-name.ext
  keyframes-reference-storyboard-contact-sheet-name.jpg
  brief.md
  product-brief-产品信息.md
  outputs/
    reference-video-storyboard-原视频场景变化分镜.md
    creative-script-directions-创意脚本方向.md
  _system-review-系统复查资料/
    ai-input-pack.md
    frame-index.json
    run-manifest.json
    video_metadata.json
```

If `--keep-work` or `-KeepWork` is used, the folder also contains `keyframes-work/` with intermediate frames and FFmpeg logs.

### Processing Details

The single-video engine:

1. Resolves `ffmpeg` and `ffprobe`.
2. Resolves the source video path.
3. Creates a dated material folder.
4. Copies or moves the source video to `original-name.ext`.
5. Copies a provided product brief or writes a TODO template to `product-brief-产品信息.md`.
6. Runs `ffprobe` and writes structured metadata to `video_metadata.json`.
7. Extracts uniform frames at one frame per second into the work directory.
8. Detects scene-change frames using FFmpeg scene threshold logic.
9. Extracts uniformly spaced selected frames across the duration.
10. Writes `frame-index.json` with timestamps and contact sheet positions.
11. Builds a 4-column tiled contact sheet from selected frames.
12. Writes `brief.md` and output skeleton markdown files.
13. Writes `ai-input-pack.md` to tell the agent what to read.
14. Writes `run-manifest.json` for reproducibility and validation.
15. Deletes `keyframes-work/` unless keep-work is enabled.
16. Prints a JSON result with paths for the agent.

The selected frame timestamps start around `0.03s` and end at `duration - 0.35s`, with an early lower bound to avoid negative or invalid timestamps on short clips.

### Orchestration And Validation

The bash `process-reference-video-phase1.sh` wraps `start-reference-video.sh`, then runs `check-creative-material.sh --json` against the generated folder.

It appends these fields to the JSON output:

- `check_status`
- `check_errors`
- `check_warnings`
- `next_step`

The PowerShell phase-one script follows the same purpose: start processing first, then validate the generated folder.

## Mix Mode

Mix mode processes two or more same-direction videos into one shared material folder. It is used when the user says multiple videos belong to one direction, hook type, test batch, or shared theme.

Primary scripts:

- bash: `scripts/process-reference-videos-mix.sh`
- PowerShell: `scripts/process-reference-videos-mix.ps1`

### Input Contract

Required inputs:

- at least two video paths
- slug
- name

Bash receives videos as a comma-separated string:

```bash
--videos "/path/a.mp4,/path/b.mp4"
```

PowerShell receives a string array:

```powershell
-VideoPaths "C:\a.mp4","C:\b.mp4"
```

Mix mode defaults to `8` selected frames per video.

### Folder Contract

Mix mode creates:

```text
creative-materials/YYYY-MM-DD-slug-name/
  video-01-source-name.ext
  video-02-source-name.ext
  keyframes-reference-storyboard-contact-sheet-name-video-01.jpg
  keyframes-reference-storyboard-contact-sheet-name-video-02.jpg
  brief.md
  product-brief-产品信息.md
  outputs/
    shared-analysis-同方向素材共性拆解.md
  _system-review-系统复查资料/
    ai-input-pack.md
    frame-index.json
    run-manifest.json
    video_metadata.json
```

### Processing Details

The mix script:

1. Validates at least two videos.
2. Validates slug, name, frame count, and FFmpeg tools.
3. Creates a single dated material folder.
4. Copies or moves each source video into the root as `video-NN-original-name.ext`.
5. Probes metadata for every copied video.
6. Extracts uniformly spaced selected frames for each video.
7. Builds one contact sheet per video.
8. Writes `video_metadata.json` with a `mode: mix` object and a `videos` array.
9. Writes `frame-index.json` with per-video frame arrays.
10. Writes a shared `brief.md`.
11. Writes `outputs/shared-analysis-同方向素材共性拆解.md`.
12. Writes `ai-input-pack.md` and `run-manifest.json`.
13. Deletes `keyframes-work/` unless keep-work is enabled.
14. Prints a JSON result with paths for the agent.

Unlike single mode, mix mode does not create independent output files for each video. Its purpose is direction-level analysis across the batch.

## Generated System Files

The `_system-review-系统复查资料/` directory is the automation and review area. It exists so human-facing files stay simple while machines have reliable structured inputs.

### `video_metadata.json`

Single mode includes:

- generation timestamp
- source video action, copied or moved
- material folder path
- stored video filename
- video codec, resolution, FPS, duration, frame count when available
- audio metadata when available
- format duration, size, and bitrate

Mix mode includes:

- generation timestamp
- `mode: mix`
- per-video index, filename, duration, dimensions, and codec

### `frame-index.json`

Single mode includes:

- source video filename
- contact sheet filename
- frame count
- selection method
- frame index, timestamp, work filename, contact sheet row and column, and AI instruction

Mix mode includes:

- `mode: mix`
- frame count per video
- per-video contact sheet filename
- per-video selected frame timestamps

### `ai-input-pack.md`

This is the agent handoff file. It lists the paths the agent should read and repeats the first-stage rules:

- fill the skeleton analysis files
- use the product brief for product mapping
- do not invent product facts
- create a story-direction pool only
- do not create production scripts or prompt folders until a direction is selected

### `run-manifest.json`

This records the generated paths and run details. It is useful for validation, debugging, and future automation.

Single mode also records frame counts for selected, uniform, and scene-detected frames.

## Human-Facing Markdown Files

The material folder root is for files a strategist, producer, or creative reviewer should open directly.

### `brief.md`

Single mode describes:

- source video
- video duration and dimensions
- generated assets
- required AI output files
- product context reminder

Mix mode describes:

- all source videos
- generated assets
- shared direction placeholder
- product mapping reminder

### `product-brief-产品信息.md`

This is the product-context gate.

If the user provides a product brief, the scripts copy it into the material root. If not, the scripts create a TODO template covering:

- product basics
- core gameplay
- sellable hooks
- constraints
- mapping goal
- privacy reminder

The skill instructions require the agent to treat TODO or incomplete product information as a blocker for complete product mapping. The agent may still deconstruct the reference video, but must mark mapping as pending and ask for missing product facts.

### `outputs/`

Single mode skeleton outputs:

- `reference-video-storyboard-原视频场景变化分镜.md`
- `creative-script-directions-创意脚本方向.md`

Mix mode skeleton output:

- `shared-analysis-同方向素材共性拆解.md`

The agent is expected to replace TODO placeholders in these files after reading the system pack, metadata, frame index, contact sheet, and product brief.

## Validation

Validation scripts:

- bash: `scripts/check-creative-material.sh`
- PowerShell: `scripts/check-creative-material.ps1`

The validator checks:

- `brief.md`
- `product-brief-产品信息.md`
- `_system-review-系统复查资料/`
- `video_metadata.json`
- `run-manifest.json`
- `frame-index.json`
- `ai-input-pack.md`
- at least one contact sheet
- at least one source video pattern, either `original-*` or `video-*`
- expected output files for either single or mix mode
- TODO placeholders in non-system markdown files

Validation status fails on errors. In strict mode, warnings fail too.

The bash validator can emit either human-readable output or JSON via `--json`.

## Environment Checks

Environment scripts:

- bash: `scripts/check-environment.sh`
- PowerShell: `scripts/check-environment.ps1`

The bash check verifies:

- `ffmpeg`
- `ffprobe`
- `python3`
- bash version

It prints install guidance for macOS, especially `brew install ffmpeg`.

The runtime scripts rely on FFmpeg/FFprobe for media processing and use Python 3 for JSON generation and parsing in the bash implementation.

## Bash And PowerShell Parity

The repository maintains bash and PowerShell implementations of the same workflow.

Bash runtime is used by installed macOS Codex, Cursor, and WorkBuddy skills. PowerShell runtime supports Windows Codex usage and is bundled inside the Codex skill source.

The implementations are intentionally similar:

- same folder names
- same material root contract
- same system files
- same copy-by-default behavior
- same product brief gate
- same single and mix mode distinction
- same first-stage-only AI rule

They are not byte-for-byte ports. For example, bash uses small Python snippets for JSON writes and parsing, while PowerShell uses native objects and `ConvertTo-Json`.

## Safety Behavior

Important safety choices:

- Existing material folders are never overwritten. A duplicate dated slug/name path fails.
- Source videos are copied by default.
- Moving source videos requires an explicit flag.
- Existing skill installs are not overwritten unless `--force`, `-Force`, `--backup`, or `-Backup` is used.
- Intermediate work directories are removed only under the generated material folder.
- Private media and generated outputs are ignored by git.
- Product facts are never invented by the skill instructions when the product brief is incomplete.

## Development Workflow

When changing shell scripts:

```bash
bash -n scripts/*.sh
```

When changing PowerShell scripts, validate syntax in PowerShell:

```powershell
$files = Get-ChildItem scripts -Filter *.ps1
foreach ($file in $files) {
  $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
}
```

For installer changes, test the non-destructive path first:

```bash
bash scripts/install-skill.sh --help
```

For generated material changes, run a real or tiny sample video through:

```bash
bash scripts/process-reference-video-phase1.sh \
  --video /path/to/reference.mp4 \
  --slug test-reference \
  --name test-reference-测试 \
  --base-dir .tmp/creative-materials
```

Then validate:

```bash
bash scripts/check-creative-material.sh \
  --material-dir .tmp/creative-materials/YYYY-MM-DD-test-reference-test-reference-测试 \
  --json
```

## Extending The Skill

Use these rules when adding new behavior:

- Keep deterministic operations in scripts, not in agent prose.
- Keep human-facing files in the material root.
- Keep machine-readable review files in `_system-review-系统复查资料/`.
- Preserve copy-by-default behavior.
- Do not create production folders during first-stage processing.
- Add new required generated files to both runtime scripts and validation scripts.
- Update all three agent packages if behavior affects Codex, Cursor, and WorkBuddy.
- Keep README as the entry guide and put longer explanations in `docs/`.

