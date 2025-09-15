#/!/usr/bin/env just

# Run the iOS app
run-ios:
    @echo "Running iOS app..."
    npx react-native run-ios

# Run the Android app
run-android:
    @echo "Running Android app..."
    npx react-native run-android

# Run the React Native app
run-react-native:
    @echo "Running React Native app..."
    npx react-native start

# Run the web app
run-web:
    @echo "Running web app..."
    ./node_modules/.bin/webpack-dev-server --config ./webpack.config.js --live-reload --color --mode development
