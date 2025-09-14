#/!/usr/bin/env just

# Update git submodules
update-submodules:
    @echo "Updating git submodules..."
    git submodule update --init --recursive --remote --merge