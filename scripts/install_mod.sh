#!/bin/bash
set -eu

# Install the mod into Factorio's mods folder by creating a symlink.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
MODNAME="personal_logistic_plates"

if [[ "$OSTYPE" == "darwin"* ]]; then
    MODS_DIR="$HOME/Library/Application Support/factorio/mods"
else
    MODS_DIR="${FACTORIO_MODS_DIR:-$HOME/.factorio/mods}"
fi

TARGET="$MODS_DIR/$MODNAME"

echo "Installing mod from: $REPO_DIR"
echo "Target mod path: $TARGET"

if [ ! -d "$MODS_DIR" ]; then
  echo "Creating mods directory: $MODS_DIR"
  mkdir -p "$MODS_DIR"
fi

if [ -L "$TARGET" ]; then
  echo "Removing existing symlink: $TARGET"
  rm "$TARGET"
elif [ -d "$TARGET" ]; then
  echo "Removing existing directory: $TARGET"
  rm -rf "$TARGET"
fi

# Create symlink (the mod files are at repo root, not in subdirectory)
ln -s "$REPO_DIR" "$TARGET"

echo "Symlink created: $TARGET -> $REPO_DIR"
