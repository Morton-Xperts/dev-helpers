#!/bin/bash
echo "This script will delete all Cocoa Pods and cache from the machine.  Additionally, it will clear all pods"
echo "downloaded to the ios/pods directory."
echo "This script should be ran from the repository root."

# check for package.json file to ensure we're at the root of the repository
if [ ! -f "package.json" ]; then
  echo "Error: This script must be ran from the root of the repository"
  exit 1
fi

sudo chown -R $USER ~/Library/Caches/CocoaPods
sudo chown -R $USER ios/Pods || echo "No Pods directory"
sudo chown -R $USER ios/Podfile.lock || echo "No Podfile.lock file"
sudo chmod -R 777 ios/Pods

# Delete all Cocoa Pods and cache from the machine
echo "Clearing Pod Caches..."
pod cache clean --all

echo "Deleting all Cocoa Pods and cache from the machine..."
rm -rf ~/Library/Caches/CocoaPods
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Clear all pods downloaded to the ios/pods directory
echo "Clearing all pods downloaded to the ios/pods directory..."
rm -rf ios/Pods/

# Reset pods
cd ios && pod setup && pod update && pod install && cd ..
