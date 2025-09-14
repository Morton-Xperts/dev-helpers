#/!/usr/bin/env just

# Generate an RSA 2048 private key and CSR using OpenSSL
# Params:
#   email: User email address (required)
#   cn:    Common Name, e.g., "Your Name Dev Key" (required)
#   out:   Output directory (optional; defaults to current directory)
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

