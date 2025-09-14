#/!/usr/bin/env just

# Open the frontend application in the browser
open-frontend:
    #/usr/bin/env bash
    @echo "Opening frontend application..."
    open http://localhost:3000

# Start the frontend services using Yarn in the foreground
start-frontend:
    #/usr/bin/env bash
    @echo "Starting frontend services..."
    # This is a placeholder; replace with actual frontend start command
    export REACT_APP_API_BASE_URL="http://localhost:8000/api"
    cd web_app && yarn install && yarn build && yarn start
    echo "Frontend services started. Access the frontend at http://localhost:3000 or run 'just open-frontend' to open it in your browser."

# Configure app environment (development, staging, production)
configure-app env="":
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
        FLAVOR="qa"
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
