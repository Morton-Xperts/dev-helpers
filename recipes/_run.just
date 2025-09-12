#/!/usr/bin/env just

# Run the iOS app
run-ios:
    @echo "Running iOS app..."
    @./scripts/exports.sh && npx react-native run-ios

# Run the Android app
run-android:
    @echo "Running Android app..."
    @./scripts/exports.sh && npx react-native run-android

# Run the React Native app
run-react-native:
    @echo "Running React Native app..."
    @./scripts/exports.sh && npx react-native start

# Run the web app
run-web:
    @echo "Running web app..."
    @./scripts/exports.sh && ./node_modules/.bin/webpack-dev-server --config ./webpack.config.js --live-reload --color --mode development
