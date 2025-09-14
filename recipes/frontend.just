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
