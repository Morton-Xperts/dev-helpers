#/!/usr/bin/env just

# Stops any running Gradle daemons
[working-directory: 'android']
stop-gradle: ensure-android-sdks
    @echo "Stopping Gradle daemons..."
    ./gradlew --stop && ./gradlew clean

# Cleans Gradle
[working-directory: 'android']
clean-gradle: ensure-android-sdks
    @echo "Cleaning Gradle..."
    ./gradlew clean

# Stops daemons and cleans Gradle
nuke-gradle: stop-gradle kill-java clean-gradle

# Kills all Java processes
kill-java:
    @echo "Killing all Java processes..."
    pkill -f java || echo "No Java processes found."

# Ensures that proper SDKs are active, outputting all info to nothing
ensure-android-sdks:
    #!/bin/zsh
    source "$HOME/.sdkman/bin/sdkman-init.sh" > /dev/null 2>&1 || echo "Failed to source SDKMAN."
    sdk env install > /dev/null 2>&1 || echo "Failed to ensure Android SDKs."
    cd android && sdk env install > /dev/null 2>&1 || echo "Failed to ensure Android SDKs."

# Increment Android versionCode in build.gradle
increment-android-version-code:
    #!/usr/bin/env bash
    set -euo pipefail

    TARGET_FILE="android/app/build.gradle"
    if [ ! -f "$TARGET_FILE" ]; then
      echo "Error: $TARGET_FILE not found." >&2
      exit 1
    fi

    python3 - <<'PY'
    import pathlib
    import re

    path = pathlib.Path("android/app/build.gradle")
    content = path.read_text()

    pattern = re.compile(r"(versionCode\s+)(\d+)")

    def replacer(match: re.Match) -> str:
        current = int(match.group(2))
        updated = current + 1
        print(f"Incrementing Android versionCode: {current} -> {updated}")
        return f"{match.group(1)}{updated}"

    new_content, count = pattern.subn(replacer, content, count=1)

    if count != 1:
        raise SystemExit("Expected to update exactly one versionCode entry.")

    path.write_text(new_content)
    PY

# Build Android app
build-android env="staging":
    #!/usr/bin/env bash
    set -euo pipefail

    if ! command -v jq >/dev/null 2>&1; then
      echo "Error: jq is required to parse android.json. Please install jq." >&2
      exit 1
    fi

    # Resolve config from android.json
    NODE_VERSION=18
    ENV_NAME=staging
    AAB_PATH='android/app/build/outputs/bundle/release/app-release.aab'
    MANIFESTS_PATH='android/app/build/intermediates/merged_manifests'
    DEBUG_PATH='android/app/build/intermediates/merged_native_libs/release/out/lib'

    if [ -f android.json ]; then
      v() { jq -r "$1 // empty" android.json 2>/dev/null || true; }
      nv=$(v '.nodeVersion'); [ -n "$nv" ] && NODE_VERSION="$nv"
      ap=$(v '.aabPath'); [ -n "$ap" ] && AAB_PATH="$ap"
      mp=$(v '.manifestsPath'); [ -n "$mp" ] && MANIFESTS_PATH="$mp"
      dp=$(v '.debugSymbolsPath'); [ -n "$dp" ] && DEBUG_PATH="$dp"
    fi

    # Override env if provided
    if [ -n "{{env}}" ]; then ENV_NAME="{{env}}"; fi

    echo "Android build config:";
    echo "  node version:   $NODE_VERSION";
    echo "  env name:       $ENV_NAME";
    echo "  aab path:       $AAB_PATH";
    echo "  manifests path: $MANIFESTS_PATH";
    echo "  debug path:     $DEBUG_PATH";

    # Ensure Android SDKs
    just ensure-android-sdks || true

    # Check JDK
    if command -v java >/dev/null 2>&1; then
      JV=$(java -version 2>&1 | head -n1 || true)
      echo "Java: $JV"
      if ! java -version 2>&1 | grep -q 'version "17'; then
        echo "Warning: JDK 17 is recommended for Android builds."
      fi
    else
      echo "Warning: Java not found on PATH; ensure JDK 17 is installed."
    fi

    # Setup Node via nvm if available
    NVM_DIR="$HOME/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
      . "$NVM_DIR/nvm.sh"
      nvm install "$NODE_VERSION"
      nvm use "$NODE_VERSION"
    else
      echo "Note: nvm not found; continuing with system Node."
    fi

    corepack enable || true

    # Configure app environment via recipe
    just configure-app "$ENV_NAME"

    # Increment Android versionCode before building to ensure uniqueness
    just increment-android-version-code

    # Run the build
    echo "This script will build the Android app."
    echo "This script should be ran from the repository root."

    # check for package.json file to ensure we're at the root of the repository
    if [ ! -f "package.json" ]; then
      echo "Error: This script must be ran from the root of the repository"
      exit 1
    fi

    #############################################
    # Install yarn dependencies
    echo "Installing yarn dependencies..."
    yarn install --frozen-lockfile
    # Get @react-native-community/cli-platform-android version from package.json
    # RN_CLI_PLATFORM_ANDROID_VERSION=$(node -p "require('./package.json')['dependencies']['@react-native-community/cli-platform-android']")
    # Install @react-native-community/cli-platform-android
    # yarn add @react-native-community/cli-platform-android@$RN_CLI_PLATFORM_ANDROID_VERSION

    #############################################
    # Set up variables & files

    echo "Setting up Android SDK root"
    export ANDROID_SDK_ROOT=~/Library/Android/sdk


    #############################################
    # Build the app

    echo "Building the app..."
    cd android
    # Build Android App Bundle (AAB) for the default release variant
    sh ./gradlew bundleRelease --stacktrace -x test


    echo "Build complete. Outputs:"
    echo "  AAB:        $AAB_PATH"
    echo "  Manifests:  $MANIFESTS_PATH"
    echo "  Debug libs: $DEBUG_PATH"

# Uninstall Android app from connected device
uninstall-android:
    #!/usr/bin/env bash
    echo "Uninstalling Android app from connected device..."
    PACKAGE_NAME=$(xmllint --xpath 'string(//manifest/@package)' android/app/src/main/AndroidManifest.xml)
    echo "Uninstalling package: $PACKAGE_NAME"
    adb uninstall $PACKAGE_NAME || echo "Failed to uninstall app; it may not be installed."
