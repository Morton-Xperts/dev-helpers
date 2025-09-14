#/!/usr/bin/env just

# Loads the Node Version Manager configuration
[private]
load-nvmrc:
    zsh ./scripts/load-nvmrc.sh

# Install dependencies
install:
   @echo "Installing dependencies..."
   yarn

# Ensure SDKs are installed and selected
init:
    @echo "Initializing project for development..."
    @just ensure-android-sdks
    @just load-nvmrc
    @just install
    @echo "Completed initialization."

# Apply versioning to the project
apply-version:
    python3 ./scripts/apply-version.py
