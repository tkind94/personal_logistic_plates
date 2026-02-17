#!/bin/bash
set -euo pipefail

# Package the mod into a zip file.
# The mod files are at the repo root (not in a subdirectory).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Locate info.json (repo root or mod folder)
if [ -f "$REPO_DIR/info.json" ]; then
    INFO_JSON="$REPO_DIR/info.json"
elif [ -f "$REPO_DIR/personal_logistic_plates/info.json" ]; then
    INFO_JSON="$REPO_DIR/personal_logistic_plates/info.json"
else
    echo "Error: info.json not found at $REPO_DIR"
    exit 1
fi

# Extract name and version from info.json
get_json_value() {
    local key=$1
    local file="${INFO_JSON:-$REPO_DIR/info.json}"
    if command -v jq >/dev/null 2>&1; then
        jq -r ".${key}" "$file"
    else
        grep -o "\"$key\": *\"[^\"]*\"" "$file" | cut -d'"' -f4
    fi
}

NAME=$(get_json_value "name")
VERSION=$(get_json_value "version")

if [ -z "$NAME" ] || [ -z "$VERSION" ]; then
    echo "Error: Could not parse name or version from info.json"
    exit 1
fi

FULL_NAME="${NAME}_${VERSION}"
ZIP_NAME="${FULL_NAME}.zip"

echo "Packaging mod: $NAME v$VERSION"

# Create a temp build directory
BUILD_DIR=$(mktemp -d)
MOD_DIR="$BUILD_DIR/$FULL_NAME"
mkdir -p "$MOD_DIR"

# Copy mod files (excluding dev/git files)
rsync -a --exclude='.git' --exclude='.github' --exclude='.gitignore' \
    --exclude='scripts' --exclude='.agent' --exclude='.vscode' \
    --exclude='*.zip' --exclude='.releaserc' \
    --exclude='*_original_*.png' \
    "$REPO_DIR/" "$MOD_DIR/"

# Create the zip
cd "$BUILD_DIR"
zip -qr "$REPO_DIR/$ZIP_NAME" "$FULL_NAME"
cd "$REPO_DIR"

# Cleanup
rm -rf "$BUILD_DIR"

echo "Created package: $ZIP_NAME"

# Output for GitHub Actions
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "artifact_name=$ZIP_NAME" >> "$GITHUB_OUTPUT"
    echo "mod_name=$NAME" >> "$GITHUB_OUTPUT"
    echo "version=$VERSION" >> "$GITHUB_OUTPUT"
fi
