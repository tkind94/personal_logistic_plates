#!/bin/bash
set -e

# Mod files are at the repo root
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Function to extract version from info.json content
get_version() {
    if command -v jq >/dev/null 2>&1; then
        echo "$1" | jq -r .version
    else
        echo "$1" | grep -o '"version": *"[^"]*"' | cut -d'"' -f4
    fi
}

# Function to check if version exists in changelog
check_changelog() {
    local version="$1"
    local changelog_file_root="$REPO_DIR/changelog.txt"
    local changelog_file_mod="$REPO_DIR/personal_logistic_plates/changelog.txt"

    # Prefer root changelog, fall back to mod folder changelog
    local changelog_file="$changelog_file_root"
    if [ ! -f "$changelog_file" ] && [ -f "$changelog_file_mod" ]; then
        changelog_file="$changelog_file_mod"
    fi

    if [ ! -f "$changelog_file" ]; then
        echo "Warning: $changelog_file not found (will be created on first release)."
        return 0  # Allow empty changelog for first release
    fi

    # Allow empty changelog for initial release
    if [ ! -s "$changelog_file" ]; then
        return 0
    fi

    if grep -q "Version: $version" "$changelog_file"; then
        return 0
    else
        return 1
    fi
}

# Main logic
IS_MAIN_PUSH=false
if [ "${1:-}" == "main" ]; then
    IS_MAIN_PUSH=true
fi

# Locate info.json (repo root or mod folder)
if [ -f "$REPO_DIR/info.json" ]; then
    INFO_JSON="$REPO_DIR/info.json"
elif [ -f "$REPO_DIR/personal_logistic_plates/info.json" ]; then
    INFO_JSON="$REPO_DIR/personal_logistic_plates/info.json"
else
    echo "Error: info.json not found."
    exit 1
fi

CURRENT_INFO=$(cat "$INFO_JSON")
CURRENT_VERSION=$(get_version "$CURRENT_INFO")

if [ -z "$CURRENT_VERSION" ]; then
    echo "Error: Could not parse version from info.json"
    exit 1
fi

echo "Current version: $CURRENT_VERSION"

# Check changelog
if check_changelog "$CURRENT_VERSION"; then
    echo "Changelog check passed."
else
    echo "Error: No changelog entry found for version $CURRENT_VERSION"
    exit 1
fi

# Check previous version if main push
if [ "$IS_MAIN_PUSH" = true ]; then
    # Only enforce version-bump if info.json was modified in this commit
    if git diff --name-only HEAD^ HEAD | grep -q -E '(^|/)info.json$'; then
        PREVIOUS_INFO=""
        if PREVIOUS_INFO=$(git show HEAD^:info.json 2>/dev/null); then
            :
        elif PREVIOUS_INFO=$(git show HEAD^:personal_logistic_plates/info.json 2>/dev/null); then
            :
        fi

        if [ -n "$PREVIOUS_INFO" ]; then
            PREVIOUS_VERSION=$(get_version "$PREVIOUS_INFO")

            if [ -n "$PREVIOUS_VERSION" ]; then
                echo "Previous version: $PREVIOUS_VERSION"
                if [ "$CURRENT_VERSION" == "$PREVIOUS_VERSION" ]; then
                    echo "Error: Version in info.json must be bumped when info.json is changed on main."
                    exit 1
                fi
            else
                echo "Warning: Could not parse previous version."
            fi
        else
            echo "Warning: Could not fetch previous version from git history (first commit?)."
        fi
    else
        echo "info.json not changed in this commit; skipping version-bump requirement for main."
    fi
else
    echo "Skipping strict version bump check (not a main push)."
fi

echo "Validation passed."
exit 0
