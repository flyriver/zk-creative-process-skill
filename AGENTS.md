# AGENTS.md

## Scope

This repository packages the `zk-creative-process` Codex skill and its PowerShell helper scripts.
The `workbuddy-macos-port` branch adds bash script ports for macOS/Linux and a WorkBuddy-compatible skill definition.

## Structure

- `skills/zk-creative-process/`: the installable, self-contained Codex skill (PowerShell/Windows).
- `skills/zk-creative-process-macos/`: the macOS/WorkBuddy skill definition (bash/Linux).
- `skills/zk-creative-process/scripts/`: PowerShell scripts bundled with the Codex skill.
- `scripts/`: repository-level copies. On `main`: PowerShell. On `workbuddy-macos-port`: bash + PowerShell.
- `docs/`: troubleshooting and longer usage notes.
- `examples/`: lightweight examples only; no private creative materials.

## Rules

- Keep the install path friendly for non-programmers: one installer command, clear next step, no silent destructive behavior.
- Default file handling must copy source videos. Moving originals requires an explicit `--move` flag (bash) or `-Move` flag (PowerShell).
- Do not commit source videos, generated `creative-materials/`, private ad data, or strategy notes.
- Keep `README.md` as the entry guide. Put longer explanations in `docs/`.
- Validate bash syntax with `bash -n` after script changes. Validate PowerShell syntax after `.ps1` changes.
