# ZK Creative Process

A Codex and Cursor skill toolkit for processing game-ad reference videos into clean creative-analysis folders.

Core workflow:

```text
reference-video deconstruction -> product-brief-产品信息.md -> map into your own product
```

## What It Creates

```text
creative-materials/YYYY-MM-DD-slug-name/
  original-name.mp4
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

`product-brief-产品信息.md` is the bridge from reference analysis to your own product. If it is empty, Codex or Cursor should not invent product facts; mapping stays pending.

## Support Matrix

| Platform | Agent | Install command | Runtime |
|----------|-------|-----------------|---------|
| Windows | Codex | `powershell -File .\scripts\install-skill.ps1` | PowerShell scripts |
| macOS | Codex | `bash scripts/install-skill.sh --agent codex` | bash scripts |
| macOS | Cursor | `bash scripts/install-skill.sh --agent cursor` | bash scripts |

## Install

### Windows / Codex

Run from this repository root:

```powershell
.\scripts\install-skill.ps1
```

If the skill already exists, the installer stops. Choose explicitly:

```powershell
.\scripts\install-skill.ps1 -Backup
.\scripts\install-skill.ps1 -Force
```

`-Backup` keeps the old installed skill. `-Force` replaces it.

### macOS / Codex and Cursor

Run from this repository root:

```bash
bash scripts/install-skill.sh --agent codex
bash scripts/install-skill.sh --agent cursor
```

`--agent` is required so the installer can choose the correct skill package and install path.

If the skill already exists, choose explicitly:

```bash
bash scripts/install-skill.sh --agent codex --backup
bash scripts/install-skill.sh --agent codex --force
bash scripts/install-skill.sh --agent cursor --backup
bash scripts/install-skill.sh --agent cursor --force
```

To install as a project-scoped Cursor skill:

```bash
bash scripts/install-skill.sh --agent cursor --project
```

`--project` is only supported with `--agent cursor`.

## Use In Codex

Single reference video:

```text
用 $zk-creative-process single 处理这个视频：C:\path\to\video.mp4
```

Same-direction batch:

```text
用 $zk-creative-process mix 把这几个同方向视频合并分析：C:\path\to\video-1.mp4, C:\path\to\video-2.mp4
```

The scripts copy source videos by default. Originals stay where they are. Use `-Move` only when you deliberately want originals moved into the material folder.

On macOS, use the bash runtime from the installed skill or the repository root. For example:

```bash
bash ~/.codex/skills/zk-creative-process/scripts/process-reference-video-phase1.sh \
  --video "/path/to/reference.mp4" \
  --slug "short-slug" \
  --name "English-Name-中文说明" \
  --base-dir "./creative-materials"
```

## Requirements

- PowerShell 7+ recommended.
- FFmpeg and FFprobe available on PATH, or pass `-FfmpegPath` and `-FfprobePath`.

Install FFmpeg on macOS:

```bash
brew install ffmpeg
```

Check environment:

```powershell
.\scripts\check-environment.ps1
```

```bash
./scripts/check-environment.sh
```

Validate generated material:

```powershell
.\scripts\check-creative-material.ps1 -MaterialDir ".\creative-materials\YYYY-MM-DD-slug-name"
```

```bash
./scripts/check-creative-material.sh --material-dir ./creative-materials/YYYY-MM-DD-slug-name
```

Validate skill metadata on Windows:

```powershell
$env:PYTHONUTF8='1'
python "$env:USERPROFILE\.codex\skills\.system\skill-creator\scripts\quick_validate.py" .\skills\zk-creative-process
```

## Docs

- [Creative process guide](docs/creative-process-guide.md)
- [Folder structure](docs/example-folder-structure.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Single example](examples/single/README.md)
- [Mix example](examples/mix/README.md)

## Privacy

- Do not commit customer videos, competitor videos, ad data, product strategy, filled product briefs, or generated `creative-materials/`.
- `.gitignore` ignores common video formats, `.tmp/`, and generated folders by default, except the bundled public sample `shower.mp4`.
- The included scripts are generic and do not depend on a private project folder.
