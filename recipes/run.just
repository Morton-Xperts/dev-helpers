#/!/usr/bin/env just

# Run from a menu chooser (fzf)
run:
    @echo "Choose a platform to run:"
    just --choose -f ./.xperts/dev-helpers/recipes/run.just -d .

# Run iOS app (checks for -for-repo override, delegates appropriately)
run-ios:
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if repo-specific override exists
    if just --list 2>/dev/null | grep -q "run-ios-for-repo"; then
        echo "Using repo-specific iOS run recipe..."
        just run-ios-for-repo
    else
        echo "Using default iOS run recipe..."
        just run-ios-internal
    fi

# Run the iOS app
run-ios-internal:
    @echo "Running iOS app..."
    NODE_OPTIONS="--openssl-legacy-provider" npx react-native run-ios

# Run Android app (checks for -for-repo override, delegates appropriately)
run-android:
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if repo-specific override exists
    if just --list 2>/dev/null | grep -q "run-android-for-repo"; then
        echo "Using repo-specific Android run recipe..."
        just run-android-for-repo
    else
        echo "Using default Android run recipe..."
        just run-android-internal
    fi

# Run the Android app
run-android-internal:
    @echo "Running Android app..."
    NODE_OPTIONS="--openssl-legacy-provider" npx react-native run-android

# Run the React Native app
run-legacy-react-native:
    @echo "Running React Native app..."
    NODE_OPTIONS="--openssl-legacy-provider" npx react-native start

# Run the React Native app
run-react-native:
    @echo "Running React Native app..."
    NODE_OPTIONS="--openssl-legacy-provider" npx react-native start

# Run the web app
run-web:
    @echo "Running web app..."
    ./node_modules/.bin/webpack-dev-server --config ./webpack.config.js --live-reload --color --mode development
