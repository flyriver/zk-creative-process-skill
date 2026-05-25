# AGENTS.md

## Scope

This repository packages the `zk-creative-process` skill and its helper scripts.

- `main` branch: Codex skill on Windows with PowerShell scripts.
- `workbuddy-macos-port` branch (legacy): WorkBuddy skill definition with bash script ports.
- `cursor-port` branch (active): Cursor Agent Skill with bash scripts for macOS/Linux.

## Structure

- `skills/zk-creative-process/`: the installable, self-contained Codex skill (PowerShell/Windows).
- `skills/zk-creative-process-cursor/`: the Cursor Agent Skill source (installs as `zk-creative-process` under `~/.cursor/skills/`).
- `skills/zk-creative-process/scripts/`: PowerShell scripts bundled with the Codex skill.
- `scripts/`: repository-level copies. On `main`: PowerShell. On `cursor-port`: bash + PowerShell.
- `docs/`: troubleshooting and longer usage notes.
- `examples/`: lightweight examples only; no private creative materials.

## Rules

- Keep the install path friendly for non-programmers: one installer command, clear next step, no silent destructive behavior.
- Default file handling must copy source videos. Moving originals requires an explicit `--move` flag (bash) or `-Move` flag (PowerShell).
- Do not commit source videos, generated `creative-materials/`, private ad data, or strategy notes.
- Keep `README.md` as the entry guide. Put longer explanations in `docs/`.
- Validate bash syntax with `bash -n` after script changes. Validate PowerShell syntax after `.ps1` changes.
- Cursor skill source lives at `skills/zk-creative-process-cursor/` but is installed as `zk-creative-process` (the YAML `name` field). Keep these in sync.
