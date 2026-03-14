#!/bin/bash
# Increment build number in Version.xcconfig on every build.
# Skips incrementing during test actions and indexing.

set -euo pipefail

# Only increment for actual builds, not tests or indexing
if [ "${ACTION:-}" = "indexbuild" ]; then
    echo "Skipping build number increment during indexing"
    exit 0
fi

CONFIG_FILE="${SRCROOT}/Version.xcconfig"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "error: Version.xcconfig not found at $CONFIG_FILE"
    exit 1
fi

# Read current build number
CURRENT_BUILD=$(grep 'CURRENT_PROJECT_VERSION' "$CONFIG_FILE" | sed 's/.*= *//')

if [ -z "$CURRENT_BUILD" ]; then
    echo "error: CURRENT_PROJECT_VERSION not found in $CONFIG_FILE"
    exit 1
fi

# Increment
NEW_BUILD=$((CURRENT_BUILD + 1))

# Write back
sed -i '' "s/CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = ${NEW_BUILD}/" "$CONFIG_FILE"

echo "Build number incremented: ${CURRENT_BUILD} → ${NEW_BUILD}"
