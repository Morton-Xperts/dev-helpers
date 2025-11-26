#/!/usr/bin/env just

package_version := `node -p "require('./package.json').version"`
project_pbxproj := "ios/rough_unit_48153.xcodeproj/project.pbxproj"
android_build_gradle := "android/app/build.gradle"

# Run the iOS app
prettify path=".":
    @echo "Running prettier..."
    prettier --write "{{path}}"

lint path=".":
    @echo "Linting..."
    eslint "{{path}}" --fix

# Keep iOS/Android app versions in sync with package.json
sync-app-version:
    @echo "Updating MARKETING_VERSION in {{project_pbxproj}} and Android versionName to {{package_version}}..."
    @PROJECT_FILE="{{project_pbxproj}}" ANDROID_FILE="{{android_build_gradle}}" PACKAGE_VERSION="{{package_version}}" python3 - <<'PY'
import os
import pathlib
import re

project_file = pathlib.Path(os.environ["PROJECT_FILE"])
android_file = pathlib.Path(os.environ["ANDROID_FILE"])
version = os.environ["PACKAGE_VERSION"]

pattern = r"MARKETING_VERSION = [^;]+;"
replacement = f"MARKETING_VERSION = {version};"

text = project_file.read_text()
new_text, occurrences = re.subn(pattern, replacement, text)

if occurrences == 0:
    raise SystemExit(f"No MARKETING_VERSION assignments found in {project_file}")

project_file.write_text(new_text)
print(f"Updated {occurrences} MARKETING_VERSION entr{'y' if occurrences == 1 else 'ies'} to {version}")

gradle_text = android_file.read_text()

def replace_version_name(match):
    return f"{match.group(1)}{match.group(2)}{version}{match.group(4)}"

gradle_text, name_occurrences = re.subn(
    r"(versionName\s+)([\"'])([^\"']+)([\"'])",
    replace_version_name,
    gradle_text,
    count=1,
)

if name_occurrences == 0:
    raise SystemExit(f"No versionName found in {android_file}")

def bump_version_code(match):
    current = int(match.group(2))
    return f"{match.group(1)}{current + 1}"

gradle_text, code_occurrences = re.subn(
    r"(versionCode\s+)(\d+)", bump_version_code, gradle_text, count=1
)

if code_occurrences == 0:
    raise SystemExit(f"No versionCode found in {android_file}")

android_file.write_text(gradle_text)
print("Updated Android versionName and incremented versionCode")
PY
