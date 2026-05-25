#!/usr/bin/env bash
#
# Install the Cursor Agent Skill with its bundled bash scripts.
#
# Default install location: ~/.cursor/skills/zk-creative-process/
# Override with --skills-dir or the CURSOR_SKILLS_DIR env var.
# Use --project to install into ./.cursor/skills/zk-creative-process/ inside
# the current working directory instead.

set -euo pipefail

SKILL_NAME="zk-creative-process"
SKILLS_DIR="${CURSOR_SKILLS_DIR:-$HOME/.cursor/skills}"
PROJECT_INSTALL=false
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_SKILL="${REPO_ROOT}/skills/zk-creative-process-cursor"

usage() {
    cat <<'USAGE'
Usage: install-cursor-skill.sh [--force|--backup] [--skills-dir DIR] [--project]

Install the zk-creative-process skill for Cursor.

Options:
  --skills-dir DIR  Cursor skills directory (default: ~/.cursor/skills)
  --project         Install into ./.cursor/skills/ in the current directory
                    (overrides --skills-dir)
  --force           Replace an existing installed skill
  --backup          Move an existing installed skill aside first
  --help, -h        Show this help

Environment:
  CURSOR_SKILLS_DIR  Same as --skills-dir
USAGE
}

FORCE=false
BACKUP=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skills-dir)
            SKILLS_DIR="$2"
            shift 2
            ;;
        --project)
            PROJECT_INSTALL=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --backup)
            BACKUP=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if $FORCE && $BACKUP; then
    echo "ERROR: Use either --force or --backup, not both." >&2
    exit 1
fi

if $PROJECT_INSTALL; then
    SKILLS_DIR="$(pwd)/.cursor/skills"
fi

DEST="${SKILLS_DIR}/${SKILL_NAME}"
SCRIPTS_DEST="${DEST}/scripts"

if [[ ! -d "$SOURCE_SKILL" ]]; then
    echo "ERROR: Skill source not found: $SOURCE_SKILL" >&2
    exit 1
fi

mkdir -p "$SKILLS_DIR"

if [[ -e "$DEST" ]]; then
    if $BACKUP; then
        BACKUP_DEST="${DEST}.backup-$(date +%Y%m%d-%H%M%S)"
        mv "$DEST" "$BACKUP_DEST"
        echo "Existing skill backed up to: $BACKUP_DEST"
    elif $FORCE; then
        rm -rf "$DEST"
    else
        echo "ERROR: Skill already exists: $DEST" >&2
        echo "Rerun with --backup to keep a backup, or --force to replace it." >&2
        exit 1
    fi
fi

mkdir -p "$DEST"
cp -R "${SOURCE_SKILL}/." "$DEST/"
mkdir -p "$SCRIPTS_DEST"
cp "${REPO_ROOT}/scripts/"*.sh "$SCRIPTS_DEST/"
chmod +x "${SCRIPTS_DEST}/"*.sh

echo "Installed ${SKILL_NAME} skill to: $DEST"
echo "Bundled scripts copied to: $SCRIPTS_DEST"
echo
echo "Next steps:"
echo "  1. Verify ffmpeg is installed: brew install ffmpeg"
echo "  2. In Cursor, ask the agent to use \$${SKILL_NAME} on a reference video."
