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
    #!/usr/bin/env python3
    import os
    import pathlib
    import re

    project_file = pathlib.Path(
        os.environ.get("PROJECT_PBXPROJ", "{{project_pbxproj}}")
    )
    android_file = pathlib.Path(
        os.environ.get("ANDROID_BUILD_GRADLE", "{{android_build_gradle}}")
    )
    version = "{{package_version}}"

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

# Generate an Apple CSR using defaults from app.config.js
apple-csr output_dir=".xperts/dev-helpers/output/apple":
    #!/usr/bin/env bash
    set -euo pipefail

    output_dir="{{output_dir}}"
    mkdir -p "$output_dir"

    config_file=""
    for candidate in app.config.ts app.config.js; do
      if [ -f "$candidate" ]; then
        config_file="$candidate"
        break
      fi
    done

    app_name=""
    bundle_id=""
    if [ -n "$config_file" ]; then
      if [ "$config_file" = "app.config.ts" ]; then
        if command -v ts-node >/dev/null 2>&1; then
          app_name="$(ts-node --transpile-only --compiler-options '{"module":"ESNext"}' -e "import { createRequire } from 'module'; globalThis.require = createRequire(import.meta.url); import config from './app.config.ts'; console.log(config?.default?.name ?? config?.name ?? '')" 2>/dev/null || true)"
          bundle_id="$(ts-node --transpile-only --compiler-options '{"module":"ESNext"}' -e "import { createRequire } from 'module'; globalThis.require = createRequire(import.meta.url); import config from './app.config.ts'; console.log(config?.default?.ios?.bundleIdentifier ?? config?.ios?.bundleIdentifier ?? '')" 2>/dev/null || true)"
        fi
      else
        app_name="$(node --input-type=module -e "import { createRequire } from 'module'; globalThis.require = createRequire(import.meta.url); const config = (await import('./app.config.js')).default; console.log(config?.name ?? '')" 2>/dev/null || true)"
        bundle_id="$(node --input-type=module -e "import { createRequire } from 'module'; globalThis.require = createRequire(import.meta.url); const config = (await import('./app.config.js')).default; console.log(config?.ios?.bundleIdentifier ?? '')" 2>/dev/null || true)"
      fi
    fi

    if [ -n "$config_file" ] && [ -z "$app_name" ] && [ -z "$bundle_id" ]; then
      app_name="$(node -e "const fs = require('fs'); const text = fs.readFileSync('app.config.js', 'utf8'); const m = text.match(/\\bname\\s*:\\s*['\\\"]([^'\\\"]+)['\\\"]/); console.log(m ? m[1] : '');" 2>/dev/null || true)"
      bundle_id="$(node -e "const fs = require('fs'); const text = fs.readFileSync('app.config.js', 'utf8'); const m = text.match(/bundleIdentifier\\s*:\\s*['\\\"]([^'\\\"]+)['\\\"]/); console.log(m ? m[1] : '');" 2>/dev/null || true)"
    fi

    default_cn="${app_name:-Cured}"
    default_org="${app_name:-Cured}"
    default_country="US"

    if [ -n "$config_file" ]; then
      echo "Defaults from ${config_file}:"
      echo "  name: ${app_name:-<missing>}"
      echo "  ios.bundleIdentifier: ${bundle_id:-<missing>}"
    else
      echo "No app.config.js or app.config.ts found; using generic defaults."
    fi
    echo ""

    read -r -p "Common Name [${default_cn}]: " cn
    read -r -p "Organization [${default_org}]: " org
    read -r -p "Country Code (2 letters) [${default_country}]: " country
    read -r -p "Email (optional): " email

    cn="${cn:-$default_cn}"
    org="${org:-$default_org}"
    country="${country:-$default_country}"

    subj="/CN=${cn}/O=${org}/C=${country}"
    if [ -n "$email" ]; then
      subj="${subj}/emailAddress=${email}"
    fi

    key_path="${output_dir}/apple.key"
    csr_path="${output_dir}/apple.csr"

    openssl genrsa -out "$key_path" 2048
    openssl req -new -key "$key_path" -out "$csr_path" -subj "$subj"

    echo ""
    echo "CSR created:"
    echo "  Key: ${key_path}"
    echo "  CSR: ${csr_path}"
