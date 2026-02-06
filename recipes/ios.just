#/!/usr/bin/env just

install-signing ios_config_path="ios.json" certificate_base64="" certificate_path="" provisioning_profiles_base64="" provisioning_profiles_path="" p12_password="" keychain_password="" keychain_name="app-signing" keychain_path="" provisioning_destination="":
    #!/usr/bin/env bash
    set -euo pipefail

    IOS_CONFIG_PATH="{{ios_config_path}}"
    CERT_BASE64="{{certificate_base64}}"
    CERT_PATH="{{certificate_path}}"
    PROFILES_BASE64="{{provisioning_profiles_base64}}"
    PROFILES_PATH="{{provisioning_profiles_path}}"
    P12_PASSWORD="{{p12_password}}"
    KEYCHAIN_PASSWORD="{{keychain_password}}"
    KEYCHAIN_NAME="{{keychain_name}}"
    KEYCHAIN_PATH_INPUT="{{keychain_path}}"
    PROVISIONING_DESTINATION="{{provisioning_destination}}"

    # Allow environment overrides for automation contexts (e.g., GitHub Actions)
    [ -n "${IOS_SIGNING_CONFIG_PATH:-}" ] && IOS_CONFIG_PATH="${IOS_SIGNING_CONFIG_PATH}"
    [ -n "${IOS_SIGNING_CERT_BASE64:-}" ] && CERT_BASE64="${IOS_SIGNING_CERT_BASE64}"
    [ -n "${IOS_SIGNING_CERT_PATH:-}" ] && CERT_PATH="${IOS_SIGNING_CERT_PATH}"
    [ -n "${IOS_SIGNING_PROFILES_BASE64:-}" ] && PROFILES_BASE64="${IOS_SIGNING_PROFILES_BASE64}"
    [ -n "${IOS_SIGNING_PROFILES_PATH:-}" ] && PROFILES_PATH="${IOS_SIGNING_PROFILES_PATH}"
    [ -n "${IOS_SIGNING_P12_PASSWORD:-}" ] && P12_PASSWORD="${IOS_SIGNING_P12_PASSWORD}"
    [ -n "${IOS_SIGNING_KEYCHAIN_PASSWORD:-}" ] && KEYCHAIN_PASSWORD="${IOS_SIGNING_KEYCHAIN_PASSWORD}"
    [ -n "${IOS_SIGNING_KEYCHAIN_NAME:-}" ] && KEYCHAIN_NAME="${IOS_SIGNING_KEYCHAIN_NAME}"
    [ -n "${IOS_SIGNING_KEYCHAIN_PATH:-}" ] && KEYCHAIN_PATH_INPUT="${IOS_SIGNING_KEYCHAIN_PATH}"
    [ -n "${IOS_SIGNING_PROVISIONING_DESTINATION:-}" ] && PROVISIONING_DESTINATION="${IOS_SIGNING_PROVISIONING_DESTINATION}"

    KEYCHAIN_NAME=${KEYCHAIN_NAME:-app-signing}
    IOS_CONFIG_PATH=${IOS_CONFIG_PATH:-ios.json}

    if [ -n "$IOS_CONFIG_PATH" ] && [ ! -f "$IOS_CONFIG_PATH" ] && [ -n "${GITHUB_WORKSPACE:-}" ]; then
      if [ -f "$GITHUB_WORKSPACE/$IOS_CONFIG_PATH" ]; then
        IOS_CONFIG_PATH="$GITHUB_WORKSPACE/$IOS_CONFIG_PATH"
      fi
    fi

    if [ -n "$IOS_CONFIG_PATH" ] && [ "${IOS_CONFIG_PATH##*.}" != "json" ]; then
      if [ -z "$KEYCHAIN_PATH_INPUT" ]; then
        KEYCHAIN_PATH_INPUT="$IOS_CONFIG_PATH"
      fi
      IOS_CONFIG_PATH="ios.json"
    fi

    HAVE_CONFIG=false
    if [ -f "$IOS_CONFIG_PATH" ]; then
      HAVE_CONFIG=true
      if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is required to parse $IOS_CONFIG_PATH" >&2
        exit 1
      fi
    fi

    read_config() {
      local query="$1"
      if $HAVE_CONFIG; then
        jq -r "$query // empty" "$IOS_CONFIG_PATH"
      else
        printf ''
      fi
    }

    if [ -z "$CERT_BASE64" ]; then
      CERT_BASE64="$(read_config '.certificateBase64')"
    fi
    if [ -z "$CERT_PATH" ]; then
      CERT_PATH="$(read_config '.certificatePath')"
    fi
    if [ -z "$PROFILES_BASE64" ]; then
      PROFILES_BASE64="$(read_config '.provisioningProfilesBase64')"
    fi
    if [ -z "$PROFILES_PATH" ]; then
      PROFILES_PATH="$(read_config '.provisioningProfilesPath')"
    fi
    if [ -z "$P12_PASSWORD" ]; then
      P12_PASSWORD="$(read_config '.p12Password')"
    fi
    if [ -z "$KEYCHAIN_PASSWORD" ]; then
      KEYCHAIN_PASSWORD="$(read_config '.keychainPassword')"
    fi
    if [ -z "$PROVISIONING_DESTINATION" ]; then
      PROVISIONING_DESTINATION="${HOME}/Library/MobileDevice/Provisioning Profiles"
    fi

    if [ -z "$KEYCHAIN_PATH_INPUT" ]; then
      KEYCHAIN_PATH_INPUT="${RUNNER_TEMP:-}"
    fi
    if [ -z "$KEYCHAIN_PATH_INPUT" ]; then
      KEYCHAIN_PATH_INPUT="${TMPDIR:-}"
    fi
    if [ -z "$KEYCHAIN_PATH_INPUT" ]; then
      KEYCHAIN_PATH_INPUT="$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || echo /tmp/)"
    fi
    case "$KEYCHAIN_PATH_INPUT" in
      */.keychain-db) KEYCHAIN_PATH="$KEYCHAIN_PATH_INPUT" ;;
      *) KEYCHAIN_PATH="${KEYCHAIN_PATH_INPUT%/}/${KEYCHAIN_NAME}.keychain-db" ;;
    esac

    LOGIN_KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"
    USE_EXISTING_KEYCHAIN=false
    if [ "$KEYCHAIN_PATH" = "$LOGIN_KEYCHAIN" ]; then
      USE_EXISTING_KEYCHAIN=true
    fi

    cleanup() {
      rm -f "${CERT_TMP:-}" "${PROFILES_TMP:-}"
      rm -rf "${PROFILES_DIR:-}"
    }
    trap cleanup EXIT

    if [ -z "$CERT_BASE64" ] && [ -n "$CERT_PATH" ] && [ -f "$CERT_PATH" ]; then
      CERT_BASE64="$(base64 < "$CERT_PATH" | tr -d '\n')"
    fi
    if [ -z "$PROFILES_BASE64" ] && [ -n "$PROFILES_PATH" ] && [ -f "$PROFILES_PATH" ]; then
      PROFILES_BASE64="$(base64 < "$PROFILES_PATH" | tr -d '\n')"
    fi

    missing=()
    [ -z "$CERT_BASE64" ] && missing+=(certificateBase64/certificatePath)
    [ -z "$P12_PASSWORD" ] && missing+=(p12Password)
    [ -z "$PROFILES_BASE64" ] && missing+=(provisioningProfilesBase64/provisioningProfilesPath)
    if ! $USE_EXISTING_KEYCHAIN; then
      [ -z "$KEYCHAIN_PASSWORD" ] && missing+=(keychainPassword)
    fi
    if [ ${#missing[@]} -gt 0 ]; then
      echo "Error: Missing signing values (${missing[*]}). Provide them in ios.json or via inputs." >&2
      exit 1
    fi

    CERT_TMP=$(mktemp -t ios_cert.XXXXXX.p12)
    printf '%s' "$CERT_BASE64" | base64 --decode > "$CERT_TMP"

    PROFILES_TMP=$(mktemp -t ios_profiles.XXXXXX.tar)
    printf '%s' "$PROFILES_BASE64" | base64 --decode > "$PROFILES_TMP"

    PROFILES_DIR=$(mktemp -d -t ios_profiles.XXXXXX)
    if tar tzf "$PROFILES_TMP" >/dev/null 2>&1; then
      tar xzf "$PROFILES_TMP" -C "$PROFILES_DIR"
    elif tar tf "$PROFILES_TMP" >/dev/null 2>&1; then
      tar xf "$PROFILES_TMP" -C "$PROFILES_DIR"
    else
      PROFILE_NAME="profile.mobileprovision"
      if [ -n "$PROFILES_PATH" ]; then
        base="${PROFILES_PATH##*/}"
        case "$base" in
          *.mobileprovision) PROFILE_NAME="$base" ;;
        esac
      fi
      mv "$PROFILES_TMP" "$PROFILES_DIR/$PROFILE_NAME"
      PROFILES_TMP=""
    fi

    mkdir -p "$PROVISIONING_DESTINATION"

    if $USE_EXISTING_KEYCHAIN; then
      if [ ! -f "$KEYCHAIN_PATH" ]; then
        echo "Error: login keychain not found at $KEYCHAIN_PATH" >&2
        exit 1
      fi
      if [ -n "$KEYCHAIN_PASSWORD" ]; then
        security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
      else
        security unlock-keychain "$KEYCHAIN_PATH" || true
      fi
    else
      if [ -f "$KEYCHAIN_PATH" ]; then
        security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
      fi
      security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
      security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
      security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
    fi

    security import "$CERT_TMP" -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH" >/dev/null
    if [ -n "$KEYCHAIN_PASSWORD" ]; then
      security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null
    else
      echo "Warning: keychain password not provided; skipping partition list update. Codesign may prompt for access." >&2
    fi

    existing_raw="$(security list-keychains -d user | sed 's/^[[:space:]]*"//;s/"$//')"
    filtered=()
    while IFS= read -r keychain; do
      [ -n "$keychain" ] || continue
      if [ "$keychain" != "$KEYCHAIN_PATH" ]; then
        filtered+=("$keychain")
      fi
    done <<EOF
    $existing_raw
    EOF

    if $USE_EXISTING_KEYCHAIN; then
      security default-keychain -s "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
    else
      security list-keychains -d user -s "$KEYCHAIN_PATH" "${filtered[@]}"
      security default-keychain -s "$KEYCHAIN_PATH"
    fi

    for provision in "$PROFILES_DIR"/*.mobileprovision; do
      [ -f "$provision" ] || continue
      uuid=$(/usr/libexec/PlistBuddy -c 'Print :UUID' /dev/stdin <<< "$(security cms -D -i "$provision")")
      cp "$provision" "$PROVISIONING_DESTINATION/$uuid.mobileprovision"
    done

    security find-identity -v -p codesigning || true

    if [ -n "${GITHUB_OUTPUT:-}" ]; then
      {
        echo "keychain_path=$KEYCHAIN_PATH"
        echo "keychain_name=$KEYCHAIN_NAME"
      } >> "$GITHUB_OUTPUT"
    fi

    echo "Signing assets installed. Keychain: $KEYCHAIN_PATH"



# Run iOS app (checks for -for-repo override, delegates appropriately)
run-ios:
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if repo-specific override exists
    if just --justfile {{justfile()}} --summary 2>/dev/null | tr ' ' '\n' | grep -q "^run-ios-for-repo$"; then
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

# Run iOS app via Expo prebuild workflow
prebuild-ios:
    @echo "Running iOS app (Expo prebuild)..."
    npx expo prebuild
    npx expo run:ios --device "iPhone 17 Pro"

# Build iOS app (checks for -for-repo override, delegates appropriately)
build-ios env="staging":
    #!/usr/bin/env bash
    set -euo pipefail

    is_expo_project() {
      if [ -f eas.json ] || [ -f app.json ] || [ -f app.config.js ] || [ -f app.config.json ]; then
        return 0
      fi
      if [ -f package.json ]; then
        if command -v node >/dev/null 2>&1; then
          node -e "const p=require('./package.json');process.exit((p.dependencies&&p.dependencies.expo)||(p.devDependencies&&p.devDependencies.expo)?0:1)" 2>/dev/null
          return $?
        fi
        if grep -q "\"expo\"" package.json; then
          return 0
        fi
      fi
      return 1
    }

    if is_expo_project; then
      echo "Expo project detected; using EAS build for iOS..."
      PROFILE_INPUT=""
      read -r -p "Enter EAS build profile (default: production): " PROFILE_INPUT
      PROFILE="${PROFILE_INPUT:-production}"
      AUTO_SUBMIT_FLAG=""
      read -r -p "Auto-submit to app stores after build? (Y/n) " AUTO_SUBMIT
      if [[ "${AUTO_SUBMIT:-y}" =~ ^[Yy]$ ]]; then
        AUTO_SUBMIT_FLAG="--auto-submit"
      fi
      npx eas build --platform ios --profile "${PROFILE}" $AUTO_SUBMIT_FLAG
      exit 0
    fi

    # Check if repo-specific override exists by trying to call it
    if just --justfile {{justfile()}} --summary 2>/dev/null | tr ' ' '\n' | grep -q "^build-ios-for-repo$"; then
        echo "Using repo-specific iOS build recipe..."
        just build-ios-for-repo "{{env}}"
    else
        echo "Using default iOS build recipe..."
        just build-ios-internal "{{env}}"
    fi

# Build iOS app but reuse the login keychain (local convenience)
build-ios-local env="staging":
    #!/usr/bin/env bash
    set -euo pipefail
    IOS_SIGNING_MODE="login" just build-ios "{{env}}"

# Build iOS app (mirrors actions/ios-build without artifact uploads)
build-ios-internal env="staging":
    #!/usr/bin/env bash
    set -euo pipefail

    SIGNING_KEYCHAIN_PATH=""
    IOS_SIGNING_MODE_INPUT="${IOS_SIGNING_MODE:-}"
    if [ -z "$IOS_SIGNING_MODE_INPUT" ] && [ "${SKIP_IOS_SIGNING:-}" = "1" ]; then
      IOS_SIGNING_MODE_INPUT="skip"
    fi
    case "${IOS_SIGNING_MODE_INPUT:-auto}" in
      auto|login|skip) ;;
      *)
        echo "Error: unsupported IOS_SIGNING_MODE '${IOS_SIGNING_MODE_INPUT}'. Expected auto, login, or skip." >&2
        exit 1
        ;;
    esac
    IOS_SIGNING_MODE_EFFECTIVE="${IOS_SIGNING_MODE_INPUT:-auto}"
    SIGNING_KEYCHAIN_CREATED=false
    SIGNING_KEYCHAIN_TOUCHED=false

    cleanup_keychain() {
      local exit_code=$1
      set +e
      if [ "$IOS_SIGNING_MODE_EFFECTIVE" = "auto" ] && $SIGNING_KEYCHAIN_TOUCHED; then
        if command -v just >/dev/null 2>&1; then
          just fix-macos-keychain >/dev/null 2>&1 || true
        else
          security default-keychain -d user -s login.keychain-db >/dev/null 2>&1 || true
          security list-keychains -d user -s \
            "$HOME/Library/Keychains/login.keychain-db" \
            "/Library/Keychains/System.keychain" >/dev/null 2>&1 || true
          security unlock-keychain "$HOME/Library/Keychains/login.keychain-db" >/dev/null 2>&1 || true
        fi
        local KEYCHAIN_TARGETS=()
        if [ -n "$SIGNING_KEYCHAIN_PATH" ]; then
          KEYCHAIN_TARGETS+=("$SIGNING_KEYCHAIN_PATH")
        fi
        local TMP_DIR
        TMP_DIR=$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || printf '')
        if [ -n "$TMP_DIR" ]; then
          KEYCHAIN_TARGETS+=("${TMP_DIR%/}/app-signing.keychain-db")
        fi
        [ -n "${RUNNER_TEMP:-}" ] && KEYCHAIN_TARGETS+=("${RUNNER_TEMP%/}/app-signing.keychain-db")
        # Deduplicate targets
        local unique_targets=()
        for kc in "${KEYCHAIN_TARGETS[@]}"; do
          [ -n "$kc" ] || continue
          local skip=false
          for existing in "${unique_targets[@]}"; do
            if [ "$existing" = "$kc" ]; then
              skip=true
              break
            fi
          done
          $skip || unique_targets+=("$kc")
        done
        for kc in "${unique_targets[@]}"; do
          [ -f "$kc" ] && security delete-keychain "$kc" >/dev/null 2>&1 || true
        done
      fi
      exit "$exit_code"
    }
    trap 'cleanup_keychain $?' EXIT

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
    DEFAULT_COCOAPODS_VERSION="1.12.1"

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
        echo "Error: CocoaPods $CP_VERSION is too old. Require >= $REQ_CP_VERSION for the configured build." >&2
        echo "Update with: BUNDLE_GEMFILE=Gemfile bundle update cocoapods" >&2
        echo "(Or lower cocoapodsMinVersion in ios.json if a newer CocoaPods is unnecessary.)" >&2
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
          echo "Error: CocoaPods $CP_VERSION is too old. Require >= $REQ_CP_VERSION for the configured build." >&2
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

    # Stage signing assets after dependencies are installed
    if [ "$IOS_SIGNING_MODE_EFFECTIVE" = "skip" ]; then
      echo "Skipping signing asset installation; assuming login.keychain-db is already configured."
    else
      if [ "$IOS_SIGNING_MODE_EFFECTIVE" = "login" ]; then
        SIGNING_KEYCHAIN_PATH="${IOS_SIGNING_KEYCHAIN_PATH:-$HOME/Library/Keychains/login.keychain-db}"
        if [ ! -f "$SIGNING_KEYCHAIN_PATH" ]; then
          echo "Error: login keychain not found at $SIGNING_KEYCHAIN_PATH" >&2
          exit 1
        fi
        SIGNING_KEYCHAIN_CREATED=false
        SIGNING_KEYCHAIN_TOUCHED=true
        IOS_SIGNING_CONFIG_PATH="$IOS_JSON" \
        IOS_SIGNING_KEYCHAIN_PATH="$SIGNING_KEYCHAIN_PATH" \
        IOS_SIGNING_KEYCHAIN_NAME="$(basename "$SIGNING_KEYCHAIN_PATH" .keychain-db)" \
        just install-signing
      else
        KEYCHAIN_TEMP_DIR=$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || printf '')
        if [ -z "$KEYCHAIN_TEMP_DIR" ]; then
          KEYCHAIN_TEMP_DIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
        fi
        KEYCHAIN_TEMP_DIR=${KEYCHAIN_TEMP_DIR%/}
        SIGNING_KEYCHAIN_PATH="${KEYCHAIN_TEMP_DIR}/app-signing.keychain-db"
        SIGNING_KEYCHAIN_CREATED=true
        SIGNING_KEYCHAIN_TOUCHED=true
        IOS_SIGNING_CONFIG_PATH="$IOS_JSON" \
        IOS_SIGNING_KEYCHAIN_PATH="$SIGNING_KEYCHAIN_PATH" \
        IOS_SIGNING_KEYCHAIN_NAME="app-signing" \
        just install-signing
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
