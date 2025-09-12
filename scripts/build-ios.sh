#!/bin/bash

echo "This script will build and stage an archive of the iOS app."
echo "This script should be ran from the repository root."

# check for package.json file to ensure we're at the root of the repository
if [ ! -f "package.json" ]; then
  echo "Error: This script must be ran from the root of the repository"
  exit 1
fi


#############################################
# Set up variables
COMMIT_HASH=$(git rev-parse --short HEAD)
VERSION=$(jq -r ".version" package.json)
MAJOR_VERSION=$(echo $VERSION | cut -d '.' -f 1)
MINOR_VERSION=$(echo $VERSION | cut -d '.' -f 2)
PATCH_VERSION=$(echo $VERSION | cut -d '.' -f 3)
WORKSPACE="polished_truth_42233.xcworkspace"
TARGET_SDK="iphonesimulator16.4"
SCHEME="Production"
APPLICATION_NAME="Nabor App"
DEVELOPER_NAME="iPhone Distribution: XXX LLC (XXXXX)"
RELEASE_BUILDDIR="/tmp/NaborApp/build"


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
  -configuration CONFIGURATION_BUILD_DIR="$RELEASE_BUILDDIR"


#############################################
# Archive and export the app
echo "Archiving and exporting.."

echo "Create the archive"
# create the archive
xcodebuild \
    -workspace "${WORKSPACE}" \
    -scheme "${SCHEME}" \
    -sdk iphoneos \
    -configuration Release archive \
    -archivePath $PWD/build/Archive/Production.xcarchive

echo "Export the app"
# export the app
xcodebuild \
  -exportArchive \
  -archivePath $PWD/build/Archive/Production.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath $PWD/build/App
