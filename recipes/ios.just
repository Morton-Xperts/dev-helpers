#/!/usr/bin/env just

# Build iOS app (mirrors actions/ios-build without artifact uploads)
build-ios env="staging":
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
    DEFAULT_COCOAPODS_VERSION="1.13.0"

    WORKSPACE=$(read_json workspace);            WORKSPACE=${WORKSPACE:-$DEFAULT_WORKSPACE}
    TARGET_SDK=$(read_json targetSdk);           TARGET_SDK=${TARGET_SDK:-$DEFAULT_TARGET_SDK}
    SCHEME=$(read_json scheme);                  SCHEME=${SCHEME:-$DEFAULT_SCHEME}
    APPLICATION_NAME=$(read_json applicationName); APPLICATION_NAME=${APPLICATION_NAME:-$DEFAULT_APPLICATION_NAME}
    DEVELOPER_NAME=$(read_json developerName);   DEVELOPER_NAME=${DEVELOPER_NAME:-$DEFAULT_DEVELOPER_NAME}
    RELEASE_BUILDDIR=$(read_json releaseBuildDir); RELEASE_BUILDDIR=${RELEASE_BUILDDIR:-$DEFAULT_RELEASE_BUILDDIR}
    COCOAPODS_VERSION=$(read_json cocoapodsVersion)
    if [ -z "$COCOAPODS_VERSION" ]; then
      COCOAPODS_VERSION=$DEFAULT_COCOAPODS_VERSION
    fi
    COCOAPODS_MIN_VERSION=$(read_json cocoapodsMinVersion)
    if [ -z "$COCOAPODS_MIN_VERSION" ]; then
      COCOAPODS_MIN_VERSION=$COCOAPODS_VERSION
    fi

    ARCHIVE_PATH_JSON=$(read_json archivePath)
    EXPORT_OPTIONS_PLIST_JSON=$(read_json exportOptionsPlist)
    EXPORT_PATH_JSON=$(read_json exportPath)

    # Ensure Ruby and CocoaPods
    gem install bundler

    # Install specified CocoaPods version
    gem install cocoapods -v "$COCOAPODS_VERSION"

    # Ensure Ruby and Bundler for CocoaPods
    bundle install

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
    just configure-app "{{env}}"

    # Resolve signing secrets
    CERT_BASE64=$(read_json certificateBase64)
    CERT_PATH=$(read_json certificatePath)
    P12_PASS=$(read_json p12Password)
    PROFILES_BASE64=$(read_json provisioningProfilesBase64)
    PROFILES_PATH=$(read_json provisioningProfilesPath)
    KEYCHAIN_PASS=$(read_json keychainPassword)
    # Optional pod source override map from ios.json
    # Format: { "podSourceOverrides": { "boost@1.76.0": { "url": "...", "checkSum": "..." } } }

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
    PP_PAYLOAD=$(mktemp -t mobile_pp.XXXXXX)
    PP_EXTRACT_DIR=$(mktemp -d -t mobile_profiles.XXXXXX)
    KEYCHAIN_PATH=$TMPDIR/app-signing.keychain-db

    echo -n "$CERT_BASE64" | base64 --decode -o "$CERTIFICATE_PATH"
    echo -n "$PROFILES_BASE64" | base64 --decode -o "$PP_PAYLOAD"

    if tar tzf "$PP_PAYLOAD" >/dev/null 2>&1; then
      tar xzf "$PP_PAYLOAD" -C "$PP_EXTRACT_DIR"
    elif tar tf "$PP_PAYLOAD" >/dev/null 2>&1; then
      tar xf "$PP_PAYLOAD" -C "$PP_EXTRACT_DIR"
    else
      PROFILE_BASENAME="${PROFILES_PATH##*/}"
      if [ -z "$PROFILE_BASENAME" ] || [ "$PROFILE_BASENAME" = "$PROFILES_PATH" ]; then
        PROFILE_BASENAME="profile.mobileprovision"
      fi
      case "$PROFILE_BASENAME" in
        *.mobileprovision) ;;
        *) PROFILE_BASENAME="${PROFILE_BASENAME%.*}.mobileprovision" ;;
      esac
      mv "$PP_PAYLOAD" "$PP_EXTRACT_DIR/$PROFILE_BASENAME"
    fi
    rm -f "$PP_PAYLOAD"

    # Create keychain if it doesn't already exist (idempotent)
    if [ -e "$KEYCHAIN_PATH" ]; then
      echo "Keychain already exists at $KEYCHAIN_PATH; skipping creation."
    else
      security create-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN_PATH"
    fi
    security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
    security unlock-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN_PATH"
    security import "$CERTIFICATE_PATH" -P "$P12_PASS" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
    security list-keychain -d user -s "$KEYCHAIN_PATH"

    mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
    for PROVISION in "$PP_EXTRACT_DIR"/*.mobileprovision; do
      [ -f "$PROVISION" ] || continue
      UUID=$(/usr/libexec/PlistBuddy -c 'Print :UUID' /dev/stdin <<< $(security cms -D -i "$PROVISION"))
      cp "$PROVISION" ~/Library/MobileDevice/Provisioning\ Profiles/$UUID.mobileprovision
    done
    security find-identity -v -p codesigning
    ls -l ~/Library/MobileDevice/Provisioning\ Profiles || true

    # Enable Corepack and install deps
    corepack enable || true
    yarn install --immutable

    # Build, archive, export
    pushd ios >/dev/null
    # Apply pod source overrides from ios.json (no repo changes, in-place during build)
    if [ -f "../ios.json" ]; then
      POD_OVERRIDES_JSON=$(jq -c '.podSourceOverrides // {}' ../ios.json)
      if [ -n "$POD_OVERRIDES_JSON" ] && [ "$POD_OVERRIDES_JSON" != "{}" ]; then
        echo "Applying pod source overrides from ios.json..."
        echo "$POD_OVERRIDES_JSON" | jq -r 'to_entries[] | "\(.key)\t\(.value.url // "")\t\(.value.checkSum // .value.sha256 // "")"' |
        while IFS=$'\t' read -r key url checksum; do
          [ -n "$url" ] || { echo "Skipping override $key: missing url"; continue; }
          name="${key%@*}"; ver="${key#*@}"
          case "$name" in
            boost)
              podspec="../node_modules/react-native/third-party-podspecs/boost.podspec"
              if [ -f "$podspec" ]; then
                [ -f "${podspec}.orig" ] || cp "$podspec" "${podspec}.orig"
                echo " - boost@$ver -> $url"
                URL="$url" SHASUM="$checksum" perl -0777 -pe "s/:http\\s*=>\\s*'[^']*'/:http => '\$ENV{URL}'/g; if (\$ENV{SHASUM}) { s/:sha256\\s*=>\\s*'[^']*'/:sha256 => '\$ENV{SHASUM}'/g }" "${podspec}.orig" > "$podspec"
              else
                echo "Warning: boost podspec not found at $podspec; skipping" >&2
              fi
              ;;
            glog)
              podspec="../node_modules/react-native/third-party-podspecs/glog.podspec"
              if [ -f "$podspec" ]; then
                [ -f "${podspec}.orig" ] || cp "$podspec" "${podspec}.orig"
                echo " - glog@$ver -> $url"
                if [[ "$url" =~ \.(zip|tar\.gz|tgz|tar\.bz2)$ ]] && [ -n "$checksum" ]; then
                  URL="$url" SHASUM="$checksum" perl -0777 -pe "s/spec\\.source\s*=\s*\{[^}]*\}/spec.source = { :http => '\$ENV{URL}',\n                  :sha256 => '\$ENV{SHASUM}' }/s" "${podspec}.orig" > "$podspec"
                else
                  URL="$url" perl -0777 -pe "s/:git\\s*=>\\s*'[^']*'/:git => '\$ENV{URL}'/g" "${podspec}.orig" > "$podspec"
                fi
              else
                echo "Warning: glog podspec not found at $podspec; skipping" >&2
              fi
              ;;
            DoubleConversion)
              podspec="../node_modules/react-native/third-party-podspecs/DoubleConversion.podspec"
              if [ -f "$podspec" ]; then
                [ -f "${podspec}.orig" ] || cp "$podspec" "${podspec}.orig"
                echo " - DoubleConversion@$ver -> $url"
                if [[ "$url" =~ \.(zip|tar\.gz|tgz|tar\.bz2)$ ]] && [ -n "$checksum" ]; then
                  URL="$url" SHASUM="$checksum" perl -0777 -pe "s/spec\\.source\s*=\s*\{[^}]*\}/spec.source = { :http => '\$ENV{URL}',\n                  :sha256 => '\$ENV{SHASUM}' }/s" "${podspec}.orig" > "$podspec"
                else
                  URL="$url" perl -0777 -pe "s/:git\\s*=>\\s*'[^']*'/:git => '\$ENV{URL}'/g" "${podspec}.orig" > "$podspec"
                fi
              else
                echo "Warning: DoubleConversion podspec not found at $podspec; skipping" >&2
              fi
              ;;
            RCT-Folly)
              podspec="../node_modules/react-native/third-party-podspecs/RCT-Folly.podspec"
              if [ -f "$podspec" ]; then
                [ -f "${podspec}.orig" ] || cp "$podspec" "${podspec}.orig"
                echo " - RCT-Folly@$ver -> $url"
                if [[ "$url" =~ \.(zip|tar\.gz|tgz|tar\.bz2)$ ]] && [ -n "$checksum" ]; then
                  URL="$url" SHASUM="$checksum" perl -0777 -pe "s/spec\\.source\s*=\s*\{[^}]*\}/spec.source = { :http => '\$ENV{URL}',\n                  :sha256 => '\$ENV{SHASUM}' }/s" "${podspec}.orig" > "$podspec"
                else
                  URL="$url" perl -0777 -pe "s/:git\\s*=>\\s*'[^']*'/:git => '\$ENV{URL}'/g" "${podspec}.orig" > "$podspec"
                fi
              else
                echo "Warning: RCT-Folly podspec not found at $podspec; skipping" >&2
              fi
              ;;
            *)
              echo "Warning: override for unsupported pod '$name' is present; no handler implemented." >&2
              ;;
          esac
        done
      fi
    fi
    # Use Bundler-managed CocoaPods when available, else fall back
    if command -v bundle >/dev/null 2>&1 && [ -f "../Gemfile" ]; then
      echo "Using Bundler for CocoaPods (Gemfile at repo root)"
      BUNDLE_GEMFILE="../Gemfile" bundle install --quiet
      # Require a CocoaPods version new enough for the configured feature set
      # Workaround Ruby 3.2 + activesupport Logger constant issue by forcing stdlib logger to load
      CP_VERSION=$(RUBYOPT="-rlogger ${RUBYOPT:-}" BUNDLE_GEMFILE="../Gemfile" bundle exec pod --version)
      REQ_CP_VERSION="$COCOAPODS_MIN_VERSION"
      if [ "$(printf '%s\n' "$CP_VERSION" "$REQ_CP_VERSION" | sort -V | head -n1)" != "$REQ_CP_VERSION" ]; then
        echo "Error: CocoaPods $CP_VERSION is too old. visionOS support requires >= $REQ_CP_VERSION." >&2
        echo "Update with: BUNDLE_GEMFILE=Gemfile bundle update cocoapods" >&2
        echo "(Or lower cocoapodsMinVersion in ios.json if visionOS is not required.)" >&2
        exit 1
      fi
      # Install Pods with retry on checksum mismatches (e.g., boost)
      if ! RUBYOPT="-rlogger ${RUBYOPT:-}" BUNDLE_GEMFILE="../Gemfile" bundle exec pod install; then
        echo "pod install failed; cleaning caches and retrying with --repo-update..." >&2
        BUNDLE_GEMFILE="../Gemfile" bundle exec pod cache clean boost --all || true
        rm -rf ~/Library/Caches/CocoaPods || true
        RUBYOPT="-rlogger ${RUBYOPT:-}" BUNDLE_GEMFILE="../Gemfile" bundle exec pod install --repo-update
      fi
    else
      if command -v pod >/dev/null 2>&1; then
        CP_VERSION=$(RUBYOPT="-rlogger ${RUBYOPT:-}" pod --version)
        REQ_CP_VERSION="$COCOAPODS_MIN_VERSION"
        if [ "$(printf '%s\n' "$CP_VERSION" "$REQ_CP_VERSION" | sort -V | head -n1)" != "$REQ_CP_VERSION" ]; then
          echo "Error: CocoaPods $CP_VERSION is too old. visionOS support requires >= $REQ_CP_VERSION." >&2
          echo "Update with: gem install cocoapods -v '>= $REQ_CP_VERSION'" >&2
          exit 1
        fi
        # Install Pods with retry on checksum mismatches (e.g., boost)
        if ! RUBYOPT="-rlogger ${RUBYOPT:-}" pod install; then
          echo "pod install failed; cleaning caches and retrying with --repo-update..." >&2
          pod cache clean boost --all || true
          rm -rf ~/Library/Caches/CocoaPods || true
          RUBYOPT="-rlogger ${RUBYOPT:-}" pod install --repo-update
        fi
      else
        echo "Error: CocoaPods not found. Install via 'gem install cocoapods' or use Bundler: 'bundle install' then re-run." >&2
        exit 1
      fi
    fi

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

# Update CocoaPods gem and lockfiles to match ios.json
update-cocoapods:
    #!/usr/bin/env bash
    set -euo pipefail

    if ! command -v jq >/dev/null 2>&1; then
      echo "Error: jq is required to read ios.json." >&2
      exit 1
    fi
    if [ ! -f "ios.json" ]; then
      echo "Error: ios.json not found. Run from the repository root." >&2
      exit 1
    fi

    TARGET_VERSION=$(jq -r '.cocoapodsVersion // empty' ios.json)
    if [ -z "$TARGET_VERSION" ]; then
      echo "Error: cocoapodsVersion not set in ios.json." >&2
      exit 1
    fi

    echo "Updating CocoaPods toolchain to $TARGET_VERSION"
    gem install bundler
    gem install cocoapods -v "$TARGET_VERSION"

    if [ ! -f Gemfile ]; then
      echo "Error: Gemfile not found. Run from the repository root." >&2
      exit 1
    fi

    BUNDLE_GEMFILE="Gemfile" bundle install
    BUNDLE_GEMFILE="Gemfile" bundle update cocoapods

    CP_VERSION=$(RUBYOPT="-rlogger ${RUBYOPT:-}" BUNDLE_GEMFILE="Gemfile" bundle exec pod --version)
    if [ "$CP_VERSION" != "$TARGET_VERSION" ]; then
      echo "Error: Bundler resolved CocoaPods $CP_VERSION, expected $TARGET_VERSION." >&2
      exit 1
    fi

    if [ -d ios ]; then
      pushd ios >/dev/null
      RUBYOPT="-rlogger ${RUBYOPT:-}" BUNDLE_GEMFILE="../Gemfile" bundle exec pod install
      popd >/dev/null
    else
      echo "Warning: ios directory not found; skipping pod install." >&2
    fi

    echo "CocoaPods updated to $TARGET_VERSION"

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

# Create a .p12 from a certificate and matching private key
make-p12 cert key name out pass="":
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v openssl >/dev/null 2>&1; then
      echo "Error: openssl is required." >&2
      exit 1
    fi
    CERT="{{cert}}"
    KEY="{{key}}"
    NAME="{{name}}"
    OUT="{{out}}"
    P12_PASS="{{pass}}"
    if [ ! -f "$CERT" ]; then
      echo "Error: cert not found at $CERT" >&2
      exit 1
    fi
    if [ ! -f "$KEY" ]; then
      echo "Error: key not found at $KEY (you need the private key that matches the certificate's CSR)." >&2
      exit 1
    fi
    if [ -z "$P12_PASS" ]; then
      P12_PASS=$(openssl rand -base64 24)
      echo "Generated p12 password." >&2
    fi
    mkdir -p "$(dirname "$OUT")"
    echo "Creating PKCS#12 at $OUT ..."
    openssl pkcs12 -export -inkey "$KEY" -in "$CERT" -out "$OUT" -name "$NAME" -passout pass:"$P12_PASS"
    echo "Done."
    echo
    echo "p12 file:        $OUT"
    echo "p12 password:    $P12_PASS"
    echo
    echo "To produce base64 for ios.json (certificateBase64):"
    echo "  base64 < '$OUT' | tr -d '\n'"
    echo
    echo "Set ios.json keys:"
    echo "  \"certificateBase64\": \"<output of base64 command>\","
    echo "  \"p12Password\": \"$P12_PASS\""

# Package provisioning profile(s) into a tar.gz for ios.json
pack-profiles in out:
    #!/usr/bin/env bash
    set -euo pipefail
    IN="{{in}}"
    OUT="{{out}}"
    if [ ! -f "$IN" ]; then
      echo "Error: provisioning profile not found at $IN" >&2
      exit 1
    fi
    mkdir -p "$(dirname "$OUT")"
    DIR=$(dirname "$IN")
    FILE=$(basename "$IN")
    echo "Creating archive $OUT from $IN ..."
    tar -czf "$OUT" -C "$DIR" "$FILE"
    echo "Done."
    echo
    echo "To produce base64 for ios.json (provisioningProfilesBase64):"
    echo "  base64 < '$OUT' | tr -d '\n'"
    echo
    echo "Set ios.json keys:"
    echo "  \"provisioningProfilesBase64\": \"<output of base64 command>\""

fix-macos-keychain:
    #!/usr/bin/env bash
    echo "Restoring login.keychain-db as default user keychain..."
    security default-keychain -d user -s login.keychain-db

    echo "Restoring user keychain search list to login + System..."
    security list-keychains -d user -s \
      "$HOME/Library/Keychains/login.keychain-db" \
      "/Library/Keychains/System.keychain"

    echo "Unlocking login.keychain-db..."
    security unlock-keychain "$HOME/Library/Keychains/login.keychain-db"

    echo "Removing temporary signing keychain if it exists..."
    TMP_KC=$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null)app-signing.keychain-db
    [ -f "$TMP_KC" ] && security delete-keychain "$TMP_KC" || true
