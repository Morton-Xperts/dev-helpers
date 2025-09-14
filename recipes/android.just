#/!/usr/bin/env just

# Stops any running Gradle daemons
[working-directory: 'android']
stop-gradle: ensure-android-sdks
    @echo "Stopping Gradle daemons..."
    ./gradlew --stop && ./gradlew clean

# Cleans Gradle
[working-directory: 'android']
clean-gradle: ensure-android-sdks
    @echo "Cleaning Gradle..."
    ./gradlew clean

# Stops daemons and cleans Gradle
nuke-gradle: stop-gradle kill-java clean-gradle

# Kills all Java processes
kill-java:
    @echo "Killing all Java processes..."
    pkill -f java || echo "No Java processes found."

# Ensures that proper SDKs are active, outputting all info to nothing
ensure-android-sdks:
    #!/bin/zsh
    source "$HOME/.sdkman/bin/sdkman-init.sh" > /dev/null 2>&1 || echo "Failed to source SDKMAN."
    sdk env install > /dev/null 2>&1 || echo "Failed to ensure Android SDKs."
    cd android && sdk env install > /dev/null 2>&1 || echo "Failed to ensure Android SDKs."