#!/bin/bash

echo "This script will build and stage an archive of the iOS app."
echo "This script should be ran from the repository root."

# check for package.json file to ensure we're at the root of the repository
if [ ! -f "package.json" ]; then
  echo "Error: This script must be ran from the root of the repository"
  exit 1
fi

# Optional: ios.json file with iOS build variables
IOS_JSON="ios.json"
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required to parse ios.json. Please install jq." >&2
  exit 1
fi

# Warn if ios.json missing; we'll fall back to defaults below
if [ ! -f "$IOS_JSON" ]; then
  echo "Warning: $IOS_JSON not found. Using built-in defaults."
fi


#############################################
# Set up variables (package info)
COMMIT_HASH=$(git rev-parse --short HEAD)
VERSION=$(jq -r ".version" package.json)
MAJOR_VERSION=$(echo "$VERSION" | cut -d '.' -f 1)
MINOR_VERSION=$(echo "$VERSION" | cut -d '.' -f 2)
PATCH_VERSION=$(echo "$VERSION" | cut -d '.' -f 3)

# Read iOS build config from ios.json with safe fallbacks
read_json() {
  local key="$1"
  if [ -f "$IOS_JSON" ]; then
    jq -r --arg k "$key" '.[$k] // .[($k | ascii_upcase)] // empty' "$IOS_JSON"
  else
    echo ""
  fi
}

# Defaults (used if ios.json missing/empty)
DEFAULT_WORKSPACE="polished_truth_42233.xcworkspace"
DEFAULT_TARGET_SDK="iphonesimulator16.4"
DEFAULT_SCHEME="Production"
DEFAULT_APPLICATION_NAME="Nabor App"
DEFAULT_DEVELOPER_NAME="iPhone Distribution: XXX LLC (XXXXX)"
DEFAULT_RELEASE_BUILDDIR="/tmp/NaborApp/build"

WORKSPACE=$(read_json workspace);            WORKSPACE=${WORKSPACE:-$DEFAULT_WORKSPACE}
TARGET_SDK=$(read_json targetSdk);           TARGET_SDK=${TARGET_SDK:-$DEFAULT_TARGET_SDK}
SCHEME=$(read_json scheme);                  SCHEME=${SCHEME:-$DEFAULT_SCHEME}
APPLICATION_NAME=$(read_json applicationName); APPLICATION_NAME=${APPLICATION_NAME:-$DEFAULT_APPLICATION_NAME}
DEVELOPER_NAME=$(read_json developerName);   DEVELOPER_NAME=${DEVELOPER_NAME:-$DEFAULT_DEVELOPER_NAME}
RELEASE_BUILDDIR=$(read_json releaseBuildDir); RELEASE_BUILDDIR=${RELEASE_BUILDDIR:-$DEFAULT_RELEASE_BUILDDIR}

echo "Using iOS build configuration:"
echo "  workspace:        $WORKSPACE"
echo "  scheme:           $SCHEME"
echo "  target SDK:       $TARGET_SDK"
echo "  release builddir: $RELEASE_BUILDDIR"


#############################################
# Reset NVM, Yarn, NPM for GitHub Actions
if [ -n "$GITHUB_ACTIONS" ]; then
  echo "Resetting NVM, Yarn, NPM..."
  source ~/.nvm/nvm.sh
  nvm deactivate
  nvm uninstall --force node
  brew uninstall --force yarn
  brew install nvm
  npm i -g yarn
fi


#############################################
# Enable corepack
corepack enable


#############################################
# Install yarn dependencies
yarn install --frozen-lockfile

# Unalias default node version
nvm unalias default
nvm alias default node


#############################################
# Build the app
echo "Building..."
cd ios

echo "Install pods"
pod install

echo "Build the app"
xcodebuild \
  -workspace "${WORKSPACE}" \
  -scheme "${SCHEME}" \
  -sdk "${TARGET_SDK}" \
  -configuration CONFIGURATION_BUILD_DIR="$RELEASE_BUILDDIR"


#############################################
# Archive and export the app
echo "Archiving and exporting.."

echo "Create the archive"
# create the archive
# Resolve archive/export paths (allow overrides via ios.json)
ARCHIVE_PATH_JSON=$(read_json archivePath)
EXPORT_OPTIONS_PLIST_JSON=$(read_json exportOptionsPlist)
EXPORT_PATH_JSON=$(read_json exportPath)

# Defaults are relative to the ios/ directory
ARCHIVE_PATH=${ARCHIVE_PATH_JSON:-"$PWD/build/Archive/${SCHEME}.xcarchive"}
EXPORT_OPTIONS_PLIST=${EXPORT_OPTIONS_PLIST_JSON:-"ExportOptions.plist"}
EXPORT_PATH=${EXPORT_PATH_JSON:-"$PWD/build/App"}

echo "  archive path:     $ARCHIVE_PATH"
echo "  export plist:     $EXPORT_OPTIONS_PLIST"
echo "  export path:      $EXPORT_PATH"

xcodebuild \
    -workspace "${WORKSPACE}" \
    -scheme "${SCHEME}" \
    -sdk iphoneos \
    -configuration Release archive \
    -archivePath "$ARCHIVE_PATH"

echo "Export the app"
# export the app
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -exportPath "$EXPORT_PATH"
