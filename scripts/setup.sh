#!/usr/bin/env bash

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install packages
brew install fzf # fuzzy finder
brew install just # command runner
brew install codex # AI pair programmer
brew install docker-compose # multi-container Docker applications
brew install nvm # Node Version Manager
brew install pyenv # Python Version Manager
brew install pyenv-virtualenv # Python virtual environments
brew install rbenv # Ruby Version Manager
brew install gh # GitHub CLI
brew install node # Node.js
brew install watchman # file watching service
brew install yarn # package manager for JavaScript
brew install azure-cli # Azure CLI
brew install react-native-cli # React Native CLI

# Install SDKMAN
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"

# Install Java 11 and 17, but set 17 as default
sdk install java 11.0.19-tem
sdk install java 17.0.8-tem
sdk default java 17.0.8-tem

# Install Ruby versions
rbenv install 2.7.8
rbenv install 3.1.4
rbenv install 3.2.2

# Set global Ruby version
rbenv global 3.2.2

# Install node packages
npm install -g eas-cli # Expo Application Services CLI
npm install -g expo-cli # Expo CLI
npm install -g firebase-tools # Firebase CLI
npm install -g cross-env
