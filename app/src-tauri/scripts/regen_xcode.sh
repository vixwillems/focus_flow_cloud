#!/usr/bin/env bash
# Regenerate the iOS Xcode project from project.yml.
#
# This is the source-of-truth pattern: project.yml is hand-edited when adding
# new sources / targets / settings, and then this script re-emits the
# focus-flow.xcodeproj that Xcode actually reads.
#
# Required tools (install with `brew install xcodegen` if missing):
#   - xcodegen
#
# Run from the repo root (or any directory — the script uses absolute paths):
#   ./app/src-tauri/scripts/regen_xcode.sh

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
GEN_DIR="${SCRIPT_DIR}/../gen/apple"
PROJECT_YML="${GEN_DIR}/project.yml"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen is not installed. Install with: brew install xcodegen" >&2
    exit 1
fi

if [ ! -f "${PROJECT_YML}" ]; then
    echo "error: project.yml not found at ${PROJECT_YML}" >&2
    exit 1
fi

echo "Regenerating Xcode project from ${PROJECT_YML}"
( cd "${GEN_DIR}" && xcodegen generate )

echo "Done. Open the project in Xcode with:"
echo "  open ${GEN_DIR}/focus-flow.xcodeproj"
