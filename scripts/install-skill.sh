#!/usr/bin/env bash

set -euo pipefail

SKILL_NAME="zk-creative-process"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_SCRIPTS="${REPO_ROOT}/scripts"
SHELL_RUNTIME=(
    check-creative-material.sh
    check-environment.sh
    process-reference-video-phase1.sh
    process-reference-videos-mix.sh
    start-reference-video.sh
)

usage() {
    cat <<'USAGE'
Usage: install-skill.sh --agent codex|cursor|workbuddy [--force|--backup] [--skills-dir DIR] [--project]

Install the zk-creative-process skill for Codex, Cursor, or WorkBuddy.

Options:
    --agent NAME      Target agent: codex, cursor, or workbuddy (required)
  --skills-dir DIR  Skills directory override
  --project         Install into ./.cursor/skills/ in the current directory
                    (Cursor only; overrides --skills-dir)
  --force           Replace an existing installed skill
  --backup          Move an existing installed skill aside first
  --help, -h        Show this help

Environment:
  CODEX_SKILLS_DIR   Default skills dir when --agent codex
  CURSOR_SKILLS_DIR  Default skills dir when --agent cursor
    WORKBUDDY_SKILLS_DIR  Default skills dir when --agent workbuddy
USAGE
}

require_value() {
    if [[ $# -lt 2 || -z "$2" ]]; then
        echo "ERROR: Missing value for $1" >&2
        usage >&2
        exit 1
    fi
}

AGENT=""
SKILLS_DIR=""
SOURCE_SKILL=""
AGENT_LABEL=""
PROJECT_INSTALL=false
FORCE=false
BACKUP=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent)
            require_value "$1" "${2-}"
            AGENT="$2"
            shift 2
            ;;
        --skills-dir)
            require_value "$1" "${2-}"
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

if [[ -z "$AGENT" ]]; then
    echo "ERROR: --agent is required." >&2
    usage >&2
    exit 1
fi

if $FORCE && $BACKUP; then
    echo "ERROR: Use either --force or --backup, not both." >&2
    exit 1
fi

case "$AGENT" in
    codex)
        if $PROJECT_INSTALL; then
            echo "ERROR: --project is only supported with --agent cursor." >&2
            exit 1
        fi
        SOURCE_SKILL="${REPO_ROOT}/skills/${SKILL_NAME}"
        SKILLS_DIR="${SKILLS_DIR:-${CODEX_SKILLS_DIR:-$HOME/.codex/skills}}"
        AGENT_LABEL="Codex"
        ;;
    cursor)
        SOURCE_SKILL="${REPO_ROOT}/skills/${SKILL_NAME}-cursor"
        if $PROJECT_INSTALL; then
            SKILLS_DIR="$(pwd)/.cursor/skills"
        else
            SKILLS_DIR="${SKILLS_DIR:-${CURSOR_SKILLS_DIR:-$HOME/.cursor/skills}}"
        fi
        AGENT_LABEL="Cursor"
        ;;
    workbuddy)
        if $PROJECT_INSTALL; then
            echo "ERROR: --project is only supported with --agent cursor." >&2
            exit 1
        fi
        SOURCE_SKILL="${REPO_ROOT}/skills/${SKILL_NAME}-workbuddy"
        SKILLS_DIR="${SKILLS_DIR:-${WORKBUDDY_SKILLS_DIR:-$HOME/.workbuddy/skills}}"
        AGENT_LABEL="WorkBuddy"
        ;;
    *)
        echo "ERROR: Unsupported agent: $AGENT" >&2
        echo "Use --agent codex, --agent cursor, or --agent workbuddy." >&2
        exit 1
        ;;
esac

DEST="${SKILLS_DIR}/${SKILL_NAME}"
SCRIPTS_DEST="${DEST}/scripts"

if [[ ! -d "$SOURCE_SKILL" ]]; then
    echo "ERROR: Skill source not found: $SOURCE_SKILL" >&2
    exit 1
fi

if [[ ! -d "$SOURCE_SCRIPTS" ]]; then
    echo "ERROR: Repository scripts not found: $SOURCE_SCRIPTS" >&2
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
for script_name in "${SHELL_RUNTIME[@]}"; do
    cp "${SOURCE_SCRIPTS}/${script_name}" "$SCRIPTS_DEST/"
    chmod +x "${SCRIPTS_DEST}/${script_name}"
done

echo "Installed ${SKILL_NAME} skill for ${AGENT_LABEL} to: $DEST"
echo "Bundled scripts copied to: $SCRIPTS_DEST"
if $PROJECT_INSTALL; then
    echo "Installed as a project-scoped Cursor skill."
fi
echo
echo "Next steps:"
echo "  1. Verify ffmpeg is installed: brew install ffmpeg"
echo "  2. In ${AGENT_LABEL}, ask the agent to use \$${SKILL_NAME} on a reference video."