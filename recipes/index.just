set dotenv-filename := "backend/.env"
set export
set quiet

import "android.just"
import "azure.just"
import "backend.just"
import "chores.just"
import "docker.just"
import "frontend.just"
import "git.just"
import "ios.just"
import "main.just"
import "mobile.just"
import "setup.just"
import "web.just"
import "xcode.just"

# Run from a menu chooser (fzf)
run:
    @echo "Choose a platform to run:"
    just --choose -f ./.xperts/dev-helpers/recipes/run.just -d .