#/!/usr/bin/env just

# Build the web app
build-web:
    @echo "Building web app..."
    @./scripts/exports.sh && ./node_modules/.bin/webpack --config ./webpack.config.js --color --mode production
