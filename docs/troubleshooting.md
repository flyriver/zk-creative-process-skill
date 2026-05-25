# Troubleshooting

# Troubleshooting

## macOS: FFmpeg/FFprobe Killed (SIGKILL / exit code 137)

If running inside a sandboxed agent environment, macOS security policy may prevent ffmpeg/ffprobe from executing directly. The binary may be killed with signal 9.

Workaround: run the scripts directly in your terminal, then ask Codex or Cursor to read the generated files.

## FFmpeg Not Found

The scripts need both `ffmpeg` and `ffprobe`.

Install options:

```powershell
winget install Gyan.FFmpeg
```

```bash
brew install ffmpeg
```

```bash
sudo apt install ffmpeg
```

If FFmpeg is installed but not on PATH, pass explicit paths:

```powershell
.\scripts\process-reference-video-phase1.ps1 `
  -VideoPath "C:\path\to\video.mp4" `
  -Slug "test-video" `
  -Name "test-video-测试视频" `
  -ProductBriefPath ".\my-product-brief.md" `
  -FfmpegPath "C:\ffmpeg\bin\ffmpeg.exe" `
  -FfprobePath "C:\ffmpeg\bin\ffprobe.exe"
```

```bash
./scripts/process-reference-video-phase1.sh \
  --video "/path/to/video.mp4" \
  --slug "test-video" \
  --name "test-video-测试视频" \
  --product-brief "./my-product-brief.md" \
  --ffmpeg "/opt/homebrew/bin/ffmpeg" \
  --ffprobe "/opt/homebrew/bin/ffprobe"
```

## PowerShell Script Execution Is Disabled (Windows Only)

If Windows blocks script execution, run PowerShell as your normal user and set:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Or run one command with bypass:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-environment.ps1
```

## Paths With Spaces Or Non-English Characters

Use quoted paths:

```powershell
-VideoPath "C:\Users\Me\Videos\test video.mp4"
```

The scripts use `-LiteralPath` internally and should support spaces and non-English characters.

## Skill Validation Fails On Windows Encoding

If `quick_validate.py` fails with a `UnicodeDecodeError`, enable UTF-8 for that terminal session:

```powershell
$env:PYTHONUTF8='1'
python "$env:USERPROFILE\.codex\skills\.system\skill-creator\scripts\quick_validate.py" .\skills\zk-creative-process
```

This repository intentionally uses Chinese filenames in generated analysis files, so UTF-8 validation is expected.

## macOS Skill Install Paths

Use the shared macOS installer from the repository root:

```bash
bash scripts/install-skill.sh --agent codex
bash scripts/install-skill.sh --agent cursor
```

Codex installs to `~/.codex/skills/zk-creative-process/`.

Cursor installs to `~/.cursor/skills/zk-creative-process/`.

If you are checking the installed runtime manually, both macOS paths should contain:

- `scripts/check-environment.sh`
- `scripts/check-creative-material.sh`
- `scripts/process-reference-video-phase1.sh`
- `scripts/process-reference-videos-mix.sh`
- `scripts/start-reference-video.sh`

## Source Video Disappeared

Current scripts copy source videos by default. Originals stay in their original folder.

If a source video was moved, check whether the command used `-Move`. That flag deliberately moves originals into the generated material folder.

## Long Videos Are Slow

The default extracts 12 selected frames plus intermediate frames. For very long videos, first trim to the ad segment or lower the frame count:

```powershell
-StoryboardFrames 8
```

## Output Contains TODO

This is expected immediately after script setup. The script creates skeleton files. Codex or Cursor should then fill:

- `product-brief-产品信息.md`
- `outputs/reference-video-storyboard-原视频场景变化分镜.md`
- `outputs/creative-script-directions-创意脚本方向.md`

For a `mix` folder, Codex should fill:

- `outputs/shared-analysis-同方向素材共性拆解.md`

## Product Mapping Looks Generic

Fill `product-brief-产品信息.md` or pass an existing file with `-ProductBriefPath`.

Without product context, Codex or Cursor should only deconstruct the reference video and list missing product questions. It should not invent gameplay, assets, audience, or compliance constraints.

## Do Not Commit Generated Materials

Generated folders may include source videos and derived frames. Keep them out of git. This repository's `.gitignore` already ignores `creative-materials/`, `.tmp/`, and common video file extensions.
