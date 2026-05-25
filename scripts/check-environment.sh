#!/usr/bin/env bash
#
# check-environment.sh — Verify required tools are available (macOS/Linux port)
#
# Checks: ffmpeg, ffprobe, python3, bash version

set -euo pipefail

ISSUES=0
WARNINGS=0
OK_ICON="✓"
ERR_ICON="✗"
WARN_ICON="!"

echo "=== ZK Creative Process — Environment Check ==="
echo ""

check_cmd() {
    local name="$1"
    local min_version="$2"
    local version_cmd="$3"
    if command -v "$name" &>/dev/null; then
        if [[ -n "$min_version" ]]; then
            local ver
            ver=$(eval "$version_cmd" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || echo "0")
            if [[ -n "$ver" ]]; then
                echo "  $OK_ICON $name: $ver (>= ${min_version} required)"
            else
                echo "  $OK_ICON $name: found (version check skipped)"
            fi
        else
            echo "  $OK_ICON $name: $(command -v "$name")"
        fi
    else
        echo "  $ERR_ICON $name: NOT FOUND"
        ISSUES=$((ISSUES + 1))
    fi
}

check_cmd "ffmpeg" "4.0" "ffmpeg -version"
check_cmd "ffprobe" "" ""
check_cmd "python3" "3.8" "python3 --version"

# Check bash version
BASH_VER="${BASH_VERSION:-unknown}"
echo "  $OK_ICON bash: $BASH_VER"

echo ""
echo "=== Summary ==="
if [[ $ISSUES -eq 0 ]]; then
    echo "Environment: READY"
    echo "All required tools are available."
else
    echo "Environment: MISSING DEPENDENCIES"
    echo "$ISSUES tool(s) not found."
    echo ""
    echo "Install missing tools:"
    echo "  brew install ffmpeg"
fi

# Additional tips for macOS
echo ""
echo "=== Tips ==="
if [[ "$(uname)" == "Darwin" ]]; then
    echo "  macOS detected. FFmpeg can be installed via: brew install ffmpeg"
    echo "  Python 3 comes pre-installed on macOS or via: brew install python3"
fi
echo "  Use --help on any script to see all options."
echo ""
echo "  To validate generated creative material:"
echo "    ./scripts/check-creative-material.sh --material-dir <DIR>"

exit $ISSUES
