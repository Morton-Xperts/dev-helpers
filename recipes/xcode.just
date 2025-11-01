#/!/usr/bin/env just

# ============================================================================
# Xcode Version Selection Recipes
# ============================================================================

# Select Xcode version interactively (fzf picker) or directly by version number
# Usage: just select-xcode-version        (shows fzf picker)
#        just select-xcode-version 16.1   (selects version 16.1 directly)
select-xcode-version version="":
    #!/usr/bin/env bash
    set -euo pipefail

    VERSION="{{version}}"

    # Find all installed Xcode versions
    XCODE_APPS=$(find /Applications -maxdepth 1 -name "Xcode*.app" 2>/dev/null | sort -V || true)

    if [ -z "$XCODE_APPS" ]; then
        echo "Error: No Xcode installations found in /Applications"
        echo "Please install Xcode from https://developer.apple.com/xcode/"
        exit 1
    fi

    # If no version specified, use fzf to select
    if [ -z "$VERSION" ]; then
        if ! command -v fzf >/dev/null 2>&1; then
            echo "Error: fzf is required for interactive selection"
            echo "Install with: brew install fzf"
            echo ""
            echo "Or specify a version directly: just select-xcode-version 16.1"
            exit 1
        fi

        echo "Available Xcode versions:"
        SELECTED=$(echo "$XCODE_APPS" | sed 's|/Applications/Xcode||g' | sed 's|_| |g' | sed 's|.app||g' | fzf --prompt="Select Xcode version: " --height=~50% --border)

        if [ -z "$SELECTED" ]; then
            echo "No version selected"
            exit 1
        fi

        # Convert display name back to app name format
        SELECTED_CLEAN=$(echo "$SELECTED" | sed 's| |_|g')
        if [ "$SELECTED_CLEAN" = "" ]; then
            XCODE_PATH="/Applications/Xcode.app/Contents/Developer"
        else
            XCODE_PATH="/Applications/Xcode_${SELECTED_CLEAN}.app/Contents/Developer"
        fi
    else
        # Direct version selection
        XCODE_PATH="/Applications/Xcode_${VERSION}.app/Contents/Developer"

        if [ ! -d "$XCODE_PATH" ]; then
            echo "Error: Xcode ${VERSION} not found at $XCODE_PATH"
            echo ""
            echo "Available Xcode versions:"
            echo "$XCODE_APPS" | sed 's|/Applications/||g'
            exit 1
        fi
    fi

    echo "Selecting Xcode at: $XCODE_PATH"
    sudo xcode-select -s "$XCODE_PATH"

    echo ""
    echo "Verifying Xcode version..."
    xcodebuild -version

    echo ""
    echo "✓ Xcode selected successfully"

# Select Xcode version 16.1 (required for iOS builds with Vouched SDK)
select-xcode-16-1:
    @just select-xcode-version 16.1

# Select the latest/default Xcode version
select-xcode-latest:
    #!/usr/bin/env bash
    set -euo pipefail

    # Find latest Xcode version
    LATEST_XCODE=$(find /Applications -maxdepth 1 -name "Xcode*.app" 2>/dev/null | sort -V | tail -n1)

    if [ -z "$LATEST_XCODE" ]; then
        echo "Error: No Xcode installations found"
        exit 1
    fi

    XCODE_PATH="${LATEST_XCODE}/Contents/Developer"
    echo "Selecting latest Xcode at: $XCODE_PATH"
    sudo xcode-select -s "$XCODE_PATH"
    xcodebuild -version
