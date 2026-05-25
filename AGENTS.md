# AGENTS.md

## Scope

This repository packages the `zk-creative-process` skill and its helper scripts.

## Structure

- `skills/zk-creative-process/`: the installable Codex skill. Windows uses PowerShell entrypoints; macOS installs this skill with bundled bash runtime scripts.
- `skills/zk-creative-process-cursor/`: the Cursor skill source installed as `zk-creative-process` under `~/.cursor/skills/`.
- `skills/zk-creative-process/scripts/`: scripts bundled with the Codex skill for direct use after installation.
- `scripts/`: repository-level copies and wrappers for development, testing, and installer entry points across PowerShell and bash workflows.
- `docs/`: troubleshooting and longer usage notes.
- `examples/`: lightweight examples only; no private creative materials.

## Rules

- Keep the install path friendly for non-programmers: one installer command, clear next step, no silent destructive behavior.
- Default file handling must copy source videos. Moving originals requires an explicit `-Move` flag or `--move` flag.
- Do not commit source videos, generated `creative-materials/`, private ad data, or strategy notes.
- Keep `README.md` as the entry guide. Put longer explanations in `docs/`.
- macOS uses a single bash installer that routes Codex into `~/.codex/skills/` and Cursor into `~/.cursor/skills/`.
- Validate bash syntax after shell changes and PowerShell syntax after `.ps1` changes.
