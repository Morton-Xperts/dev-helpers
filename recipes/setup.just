#/!/usr/bin/env just

# Setup your project for development during Crowdbotics conversion to Xperts
init-from-crowdbotics:
    #!/usr/bin/env bash

    set -euo pipefail

    # Recursively copy resources to repo root without overwriting existing files
    SRC_DIR=".xperts/dev-helpers/resources"
    if [ -d "$SRC_DIR" ]; then
        # Ensure directory structure exists
        while IFS= read -r -d '' d; do
            rel="${d#"$SRC_DIR"/}"
            [ -z "$rel" ] && continue
            dest="./$rel"
            if [ ! -d "$dest" ]; then
                mkdir -p "$dest"
                echo "created dir: $rel"
            fi
        done < <(find "$SRC_DIR" -type d -print0)

        # Copy only files that do not already exist
        while IFS= read -r -d '' f; do
            rel="${f#"$SRC_DIR"/}"
            dest="./$rel"
            if [ -e "$dest" ]; then
                echo "skip: $rel exists"
            else
                cp "$f" "$dest"
                echo "copied file: $rel"
            fi
        done < <(find "$SRC_DIR" -type f -print0)
    else
        echo "No resources directory at $SRC_DIR"
    fi

    # Ensure package.json exists; create minimal if not
    if [ ! -f package.json ]; then
        app_name="$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9._-]/-/g' -e 's/--\+/-/g' -e 's/^-\+//' -e 's/-\+$//')"
        cat > package.json <<JSON
    {
      "name": "$app_name",
      "version": "2.0.0"
    }
    JSON
        echo "created package.json"
    else
        # Ensure package.json contains a version key; add if missing
        if command -v node >/dev/null 2>&1; then
            node - <<'NODE'
    const fs = require('fs');
    const fname = 'package.json';
    try {
      const obj = JSON.parse(fs.readFileSync(fname, 'utf8'));
      if (!Object.prototype.hasOwnProperty.call(obj, 'version')) {
        obj.version = '2.0.0';
        fs.writeFileSync(fname, JSON.stringify(obj, null, 2) + '\n');
        console.log('added version to package.json');
      } else {
        console.log('package.json already has version:', obj.version);
      }
    } catch (e) {
      console.error('Error reading package.json:', e.message);
      process.exit(1);
    }
    NODE
            else
                python3 - <<'PY'
    import json
    p='package.json'
    with open(p) as f:
        obj=json.load(f)
    if 'version' not in obj:
        obj['version']='2.0.0'
        with open(p,'w') as f:
            json.dump(obj,f,indent=2)
            f.write('\n')
        print('added version to package.json')
    else:
        print('package.json already has version:', obj['version'])
    PY
        fi
    fi
