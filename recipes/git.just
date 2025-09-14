#/!/usr/bin/env just

# Update git submodules
update-submodules:
    @echo "Updating git submodules..."
    git submodule update --init --recursive --remote --merge

# Reattahes the xperts/dev-helpers repository so the head is not detached
reattach-dev-helpers:
    @echo "Reattaching xperts/dev-helpers repository..."
    cd .xperts/dev-helpers
    git status
    git fetch
    git switch main || git checkout -B main origin/main

track-dev-helpers-main:
    @echo "Setting xperts/dev-helpers to track main branch..."
    git submodule set-branch -b main .xperts/dev-helpers
    git add .gitmodules && git commit -m "chore: submodule dev-helpers track main"
