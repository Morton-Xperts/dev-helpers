#/!/usr/bin/env just

# Build iOS app (mirrors actions/ios-build without artifact uploads)
ios-build env="prd":
    #!/usr/bin/env bash
    set -euo pipefail

    if ! command -v jq >/dev/null 2>&1; then
      echo "Error: jq is required to parse ios.json. Please install jq." >&2
      exit 1
    fi

    IOS_JSON="ios.json"

    read_json() {
      local key="$1"
      if [ -f "$IOS_JSON" ]; then
        jq -r --arg k "$key" '.[$k] // .[($k | ascii_upcase)] // empty' "$IOS_JSON"
      else
        echo ""
      fi
    }

    # Resolve config with defaults (similar to scripts/build-ios.sh)
    DEFAULT_WORKSPACE="my_app.xcworkspace"
    DEFAULT_TARGET_SDK="iphonesimulator16.4"
    DEFAULT_SCHEME="Production"
    DEFAULT_APPLICATION_NAME="My App"
    DEFAULT_DEVELOPER_NAME="iPhone Distribution: XXX LLC (XXXXX)"
    DEFAULT_RELEASE_BUILDDIR="/tmp/MyApp/build"

    WORKSPACE=$(read_json workspace);            WORKSPACE=${WORKSPACE:-$DEFAULT_WORKSPACE}
    TARGET_SDK=$(read_json targetSdk);           TARGET_SDK=${TARGET_SDK:-$DEFAULT_TARGET_SDK}
    SCHEME=$(read_json scheme);                  SCHEME=${SCHEME:-$DEFAULT_SCHEME}
    APPLICATION_NAME=$(read_json applicationName); APPLICATION_NAME=${APPLICATION_NAME:-$DEFAULT_APPLICATION_NAME}
    DEVELOPER_NAME=$(read_json developerName);   DEVELOPER_NAME=${DEVELOPER_NAME:-$DEFAULT_DEVELOPER_NAME}
    RELEASE_BUILDDIR=$(read_json releaseBuildDir); RELEASE_BUILDDIR=${RELEASE_BUILDDIR:-$DEFAULT_RELEASE_BUILDDIR}

    ARCHIVE_PATH_JSON=$(read_json archivePath)
    EXPORT_OPTIONS_PLIST_JSON=$(read_json exportOptionsPlist)
    EXPORT_PATH_JSON=$(read_json exportPath)

    # Defaults are relative to the ios/ directory
    pushd ios >/dev/null
    ARCHIVE_PATH=${ARCHIVE_PATH_JSON:-"$PWD/build/Archive/${SCHEME}.xcarchive"}
    EXPORT_OPTIONS_PLIST=${EXPORT_OPTIONS_PLIST_JSON:-"ExportOptions.plist"}
    EXPORT_PATH=${EXPORT_PATH_JSON:-"$PWD/build/App"}
    popd >/dev/null

    echo "Using iOS build configuration:"
    echo "  workspace:        $WORKSPACE"
    echo "  scheme:           $SCHEME"
    echo "  target SDK:       $TARGET_SDK"
    echo "  release builddir: $RELEASE_BUILDDIR"
    echo "  archive path:     $ARCHIVE_PATH"
    echo "  export plist:     $EXPORT_OPTIONS_PLIST"
    echo "  export path:      $EXPORT_PATH"

    # Configure app environment centrally
    just configure-app env="{{env}}"

    # Resolve signing secrets
    CERT_BASE64=$(read_json certificateBase64)
    CERT_PATH=$(read_json certificatePath)
    P12_PASS=$(read_json p12Password)
    PROFILES_BASE64=$(read_json provisioningProfilesBase64)
    PROFILES_PATH=$(read_json provisioningProfilesPath)
    KEYCHAIN_PASS=$(read_json keychainPassword)

    # Allow file path fallback when base64 not provided
    if [ -z "$CERT_BASE64" ] && [ -n "$CERT_PATH" ] && [ -f "$CERT_PATH" ]; then
      CERT_BASE64=$(base64 < "$CERT_PATH" | tr -d '\n')
    fi
    if [ -z "$PROFILES_BASE64" ] && [ -n "$PROFILES_PATH" ] && [ -f "$PROFILES_PATH" ]; then
      PROFILES_BASE64=$(base64 < "$PROFILES_PATH" | tr -d '\n')
    fi

    missing=()
    [ -z "$CERT_BASE64" ] && missing+=(certificateBase64/certificatePath)
    [ -z "$P12_PASS" ] && missing+=(p12Password)
    [ -z "$PROFILES_BASE64" ] && missing+=(provisioningProfilesBase64/provisioningProfilesPath)
    [ -z "$KEYCHAIN_PASS" ] && missing+=(keychainPassword)
    if [ ${#missing[@]} -gt 0 ]; then
      echo "Error: Missing signing values: ${missing[*]} (provide in ios.json)." >&2
      exit 1
    fi

    # Install certificate and provisioning profiles
    CERTIFICATE_PATH=$(mktemp -t build_certificate.XXXXXX.p12)
    PP_ARCHIVE=$(mktemp -t mobile_pp.XXXXXX.tgz)
    KEYCHAIN_PATH=$TMPDIR/app-signing.keychain-db

    echo -n "$CERT_BASE64" | base64 --decode -o "$CERTIFICATE_PATH"
    echo -n "$PROFILES_BASE64" | base64 --decode -o "$PP_ARCHIVE"

    security create-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN_PATH"
    security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
    security unlock-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN_PATH"
    security import "$CERTIFICATE_PATH" -P "$P12_PASS" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
    security list-keychain -d user -s "$KEYCHAIN_PATH"

    mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
    tar xzvf "$PP_ARCHIVE" -C "$TMPDIR"
    for PROVISION in "$TMPDIR"/*.mobileprovision; do
      [ -f "$PROVISION" ] || continue
      UUID=$(/usr/libexec/PlistBuddy -c 'Print :UUID' /dev/stdin <<< $(security cms -D -i "$PROVISION"))
      cp "$PROVISION" ~/Library/MobileDevice/Provisioning\ Profiles/$UUID.mobileprovision
    done
    security find-identity -v -p codesigning
    ls -l ~/Library/MobileDevice/Provisioning\ Profiles || true

    # Enable Corepack and install deps
    corepack enable || true
    yarn install --frozen-lockfile

    # Build, archive, export
    pushd ios >/dev/null
    pod install

    xcodebuild \
      -workspace "${WORKSPACE}" \
      -scheme "${SCHEME}" \
      -sdk "${TARGET_SDK}" \
      -configuration CONFIGURATION_BUILD_DIR="$RELEASE_BUILDDIR"

    xcodebuild \
      -workspace "${WORKSPACE}" \
      -scheme "${SCHEME}" \
      -sdk iphoneos \
      -configuration Release archive \
      -archivePath "$ARCHIVE_PATH"

    xcodebuild \
      -exportArchive \
      -archivePath "$ARCHIVE_PATH" \
      -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
      -exportPath "$EXPORT_PATH"
    popd >/dev/null

    echo "iOS build complete. Outputs:"
    echo "  Archive: $ARCHIVE_PATH"
    echo "  Export:  $EXPORT_PATH"

# Remove CocoaPods caches and reinstall Pods
clean-pods:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "package.json" ]; then
      echo "Error: run from repository root (package.json not found)" >&2
      exit 1
    fi
    if ! command -v pod >/dev/null 2>&1; then
      echo "Error: CocoaPods not found. Install via: sudo gem install cocoapods" >&2
      exit 1
    fi
    echo "Adjusting permissions for CocoaPods caches and ios/Pods..."
    sudo chown -R "$USER" ~/Library/Caches/CocoaPods || true
    sudo chown -R "$USER" ios/Pods || echo "No Pods directory"
    sudo chown -R "$USER" ios/Podfile.lock || echo "No Podfile.lock file"
    [ -d ios/Pods ] && sudo chmod -R 777 ios/Pods || true

    echo "Clearing Pod caches..."
    pod cache clean --all || true

    echo "Deleting CocoaPods caches and DerivedData..."
    rm -rf ~/Library/Caches/CocoaPods || true
    rm -rf ~/Library/Developer/Xcode/DerivedData/* || true

    echo "Removing ios/Pods..."
    rm -rf ios/Pods/ || true

    echo "Reinstalling Pods..."
    pushd ios >/dev/null
    pod setup
    pod update
    pod install
    popd >/dev/null
    echo "Pods cleaned and reinstalled."
