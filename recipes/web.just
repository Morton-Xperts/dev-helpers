#/!/usr/bin/env just

# Build the web app
build-web:
    @echo "Building web app..."
    @./scripts/exports.sh && ./node_modules/.bin/webpack --config ./webpack.config.js --color --mode production

test-web:
    @echo "Running web app tests..."
    (cd backend/web_app && CI=1 npx react-scripts test --watchAll=false)

# Run the web app
run-web:
    @echo "Running web app..."
    ./node_modules/.bin/webpack-dev-server --config ./webpack.config.js --live-reload --color --mode development
