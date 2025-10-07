#/!/usr/bin/env just

# Run from a menu chooser (fzf)
run:
    @echo "Choose a platform to run:"
    just --choose -f ./.xperts/dev-helpers/recipes/run.just -d .

# Run the iOS app
run-ios:
    @echo "Running iOS app..."
    NODE_OPTIONS="--openssl-legacy-provider" npx react-native run-ios

# Run the Android app
run-android:
    @echo "Running Android app..."
    NODE_OPTIONS="--openssl-legacy-provider" npx react-native run-android

# Run the React Native app
run-legacy-react-native:
    @echo "Running React Native app..."
    NODE_OPTIONS="--openssl-legacy-provider" npx react-native start

# Run the React Native app
run-react-native:
    @echo "Running React Native app..."
    NODE_OPTIONS="--openssl-legacy-provider" npx react-native start

# Run the web app
run-web:
    @echo "Running web app..."
    ./node_modules/.bin/webpack-dev-server --config ./webpack.config.js --live-reload --color --mode development
