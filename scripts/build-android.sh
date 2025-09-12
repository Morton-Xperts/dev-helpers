#!/bin/bash
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
RN_CLI_PLATFORM_ANDROID_VERSION=$(node -p "require('./package.json')['dependencies']['@react-native-community/cli-platform-android']")
# Install @react-native-community/cli-platform-android
yarn add @react-native-community/cli-platform-android@$RN_CLI_PLATFORM_ANDROID_VERSION

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
