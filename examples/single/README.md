# Single Example

Windows / Codex:

```powershell
.\scripts\process-reference-video-phase1.ps1 `
  -VideoPath "C:\path\to\reference.mp4" `
  -Slug "dragon-flight" `
  -Name "dragon-flight-飞龙换场景" `
  -BaseDir ".\creative-materials" `
  -ProductBriefPath ".\my-product-brief.md"
```

macOS / Codex, Cursor, or WorkBuddy:

```bash
./scripts/process-reference-video-phase1.sh \
  --video "/path/to/reference.mp4" \
  --slug "dragon-flight" \
  --name "dragon-flight-飞龙换场景" \
  --base-dir "./creative-materials" \
  --product-brief "./my-product-brief.md"
```

The product brief is optional on both platforms. If omitted, fill the generated `product-brief-产品信息.md` before asking Codex, Cursor, or WorkBuddy for product-specific script directions.

Then ask Codex or Cursor:

```text
$zk-creative-process single .\creative-materials\2026-05-23-dragon-flight-飞龙换场景
```

On macOS, the same prompt works with a POSIX path:

```text
$zk-creative-process single ./creative-materials/2026-05-23-dragon-flight-飞龙换场景
```

In WorkBuddy, use the same skill name:

```text
$zk-creative-process single ./creative-materials/2026-05-23-dragon-flight-飞龙换场景
```
