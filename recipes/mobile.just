#/!/usr/bin/env just

# Generate an RSA 2048 private key and CSR using OpenSSL
create-csr email cn out=".":
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v openssl >/dev/null 2>&1; then
      echo "Error: openssl not found. Please install OpenSSL." >&2
      exit 1
    fi

    EMAIL="{{email}}"
    CN="{{cn}}"
    OUTDIR="{{out}}"
    if [ -z "$EMAIL" ] || [ -z "$CN" ]; then
      echo "Usage: just create-csr email=you@example.com cn='Your Name Dev Key' [out=./output-dir]" >&2
      exit 1
    fi

    mkdir -p "$OUTDIR"

    # Derive a file base name from CN (safe characters only)
    SAFE_BASE=$(echo "$CN" | tr ' ' '_' | tr -cd '[:alnum:]_.-')
    [ -z "$SAFE_BASE" ] && SAFE_BASE="certificate_request"

    KEY_FILE="$OUTDIR/${SAFE_BASE}.key"
    CSR_FILE="$OUTDIR/${SAFE_BASE}.csr"

    if [ -e "$KEY_FILE" ] || [ -e "$CSR_FILE" ]; then
      echo "Error: Output files already exist: $KEY_FILE or $CSR_FILE" >&2
      exit 1
    fi

    echo "Generating private key and CSR..."
    openssl req -new -newkey rsa:2048 -nodes \
      -keyout "$KEY_FILE" \
      -out "$CSR_FILE" \
      -subj "/emailAddress=$EMAIL/CN=$CN"

    echo "CSR generated: $CSR_FILE"
    echo "Private key:   $KEY_FILE"
    echo "Submit the CSR to your Certificate Authority. Keep the key secure."

# Configure app environment (development, staging, production)
configure-app env:
    #!/usr/bin/env bash
    set -euo pipefail
    ARG="{{env}}"
    if [ -z "$ARG" ]; then
      echo "Environment argument must be provided" >&2
      echo "Aliases accepted: development, develop, staging, stage, production, prd" >&2
      exit 1
    fi
    case "$ARG" in
      dev|development|develop)
        echo "Configuring app for development"
        FLAVOR="development"
        ;;
      qa|staging|stage)
        echo "Configuring app for qa"
        FLAVOR="staging"
        ;;
      prod|production|prd)
        echo "Configuring app for production"
        FLAVOR="production"
        ;;
      *)
        echo "Environment argument of \"dev\", \"qa\", or \"prod\" must be provided" >&2
        echo "Aliases accepted: development, develop, staging, stage, production, prd" >&2
        exit 1
        ;;
    esac
    printf "// THIS FILE IS AUTO GENERATED. DO NOT MANUALLY MODIFY. SEE EXECUTABLE 'configure'\nconst env = '$FLAVOR';\nexport default env;\n" > env.js
    echo "Wrote env.js with environment: $FLAVOR"

test-app:
    @echo "Running React Native app tests..."
    yarn test --watchAll=false
