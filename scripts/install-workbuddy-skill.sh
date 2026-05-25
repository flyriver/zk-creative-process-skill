#!/usr/bin/env bash
#
# Install the macOS/Linux WorkBuddy skill with its bundled bash scripts.

set -euo pipefail

SKILLS_DIR="${WORKBUDDY_SKILLS_DIR:-$HOME/.workbuddy/skills}"
DEST="${SKILLS_DIR}/zk-creative-process-macos"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_SKILL="${REPO_ROOT}/skills/zk-creative-process-macos"
SCRIPTS_DEST="${DEST}/scripts"

usage() {
    cat <<'USAGE'
Usage: install-workbuddy-skill.sh [--force|--backup] [--skills-dir DIR]

Options:
  --skills-dir DIR  WorkBuddy skills directory (default: ~/.workbuddy/skills)
  --force           Replace an existing installed skill
  --backup          Move an existing installed skill aside first
  --help, -h        Show this help
USAGE
}

FORCE=false
BACKUP=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skills-dir)
            SKILLS_DIR="$2"
            DEST="${SKILLS_DIR}/zk-creative-process-macos"
            SCRIPTS_DEST="${DEST}/scripts"
            shift 2
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

echo "Installed zk-creative-process macOS skill to: $DEST"
echo "Bundled scripts copied to: $SCRIPTS_DEST"
