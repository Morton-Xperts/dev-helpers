#/!/usr/bin/env just

export DOCKER_COMPOSE := "docker compose -f docker-compose.yml -f docker-compose.override.yml"

# Squish database migrations
[working-directory: 'backend']
squish-migrations:
    #!/usr/bin/env bash
    set -euo pipefail

    # 1) Choose app (directory with Django migrations)
    APPS=$(ls -d */ 2>/dev/null | sed 's#/##' | while read -r d; do
      if [ -d "$d/migrations" ] && ls "$d/migrations"/*.py >/dev/null 2>&1; then
        # Skip if only __init__.py exists
        COUNT=$(ls -1 "$d/migrations"/*.py 2>/dev/null | wc -l | tr -d ' ')
        if [ "$COUNT" -gt 1 ]; then echo "$d"; fi
      fi
    done)
    if [ -z "$APPS" ]; then
      echo "No apps with migrations found." >&2
      exit 1
    fi
    APP=$(echo "$APPS" | fzf --prompt="Select app to squash: " || true)
    if [ -z "$APP" ]; then
      echo "No app selected. Aborting." >&2
      exit 0
    fi

    # 2) List migrations for the app
    RAW=$($DOCKER_COMPOSE exec -T web python3 manage.py showmigrations "$APP")
    MIGS=$(echo "$RAW" | sed -E 's/^\s*\[[ X]\]\s*//' | sed -n '1,999p' | grep -E '^[0-9]{4}_.+')
    if [ -z "$MIGS" ]; then
      echo "No migrations found for app $APP." >&2
      exit 1
    fi

    # 3) Choose start migration
    START=$(echo "$MIGS" | fzf --prompt="Select START migration: " || true)
    if [ -z "$START" ]; then
      echo "No start migration selected. Aborting." >&2
      exit 0
    fi

    # 4) Choose end migration
    END=$(echo "$MIGS" | fzf --prompt="Select END migration: " || true)
    if [ -z "$END" ]; then
      echo "No end migration selected. Aborting." >&2
      exit 0
    fi

    echo "Squashing $APP from $START to $END..."
    $DOCKER_COMPOSE exec web python3 manage.py squashmigrations "$APP" "$START" "$END"
    echo "Done. Review the generated squashed migration under $APP/migrations."

# Migrate the database schema to the latest version
[working-directory: 'backend']
migrate app="":
    @just make-migrations "{{app}}"
    @echo "Running migrations..."
    $DOCKER_COMPOSE exec web python3 manage.py migrate {{app}}

# Migrate the database schema to the latest version
[working-directory: 'backend']
make-migrations app="":
    @echo "Making migrations..."
    $DOCKER_COMPOSE exec web python3 manage.py makemigrations {{app}}

# Migrate the database schema to the latest version and rebuild the backend
[working-directory: 'backend']
migrate-and-rebuild app="":
    @just migrate "{{app}}"
    @just rebuild-backend

# Create a superuser for the Django admin interface; credentials are taken from environment variables in .env
[working-directory: 'backend']
create-superuser:
    @echo "Creating superuser..."
    $DOCKER_COMPOSE exec web python3 manage.py createsuperuser

# Run the application in a Docker container
[working-directory: 'backend']
run-backend:
    #/usr/bin/env bash
    @just stop-backend
    @echo "Starting backend services..."
    $DOCKER_COMPOSE up -d
    @echo "Backend services started. Access the admin interface at http://localhost:8000/admin/ or run 'just open-admin' to open it in your browser."
    @echo "API documentation is available at http://localhost:8000/api-docs/ or run 'just open-api-docs' to open it in your browser."
    @echo "Frontend services can be started with 'just start-frontend'."

# Run the application in a Docker container in detached mode
[working-directory: 'backend']
run-backend-detached:
    @echo "Starting the application..."
    $DOCKER_COMPOSE up -d

# Launches the admin interface in a web browser
open-admin:
    @echo "Opening admin interface..."
    @open http://localhost:8000/admin/login/

# Open the API documentation
open-api-docs:
    #/usr/bin/env bash
    @echo "Opening API documentation..."
    open http://localhost:8000/api-docs/

# Rebuilds the web service in the backend Docker image without using cache
[working-directory: 'backend']
rebuild-backend-web:
    @echo "Rebuilding the web service..."
    $DOCKER_COMPOSE build web
    $DOCKER_COMPOSE up -d

# Rebuilds the web service in the backend Docker image without using cache
[working-directory: 'backend']
rebuild-backend:
    @echo "Rebuilding the web service..."
    $DOCKER_COMPOSE build --no-cache web
    $DOCKER_COMPOSE up -d

# Validates that specified Python packages can be imported
[working-directory: 'backend']
validate-packages imports:
    @echo "Validating package imports..."
    $DOCKER_COMPOSE exec web python -c "import {{imports}}; print('OK')"

# Runs a custom command in the web service container
[working-directory: 'backend']
run-backend-command command:
    @echo "Running custom command: {{command}}"
    $DOCKER_COMPOSE exec web {{command}}

# Change the environment by selecting from available .env files
change-env: choose-env run-backend

[private]
[working-directory: 'backend']
choose-env:
    #!/usr/bin/env python3

    import os
    import subprocess
    env_files = [f for f in os.listdir('.') if f.startswith('.env.') and f != '.env.example']
    if not env_files:
      print("No .env.* files found.")
      exit(1)
    env_names = [f[5:] for f in env_files]
    fzf = subprocess.Popen(['fzf', '--prompt=Select an environment: '], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    out, _ = fzf.communicate('\n'.join(env_names))
    env_file = out.strip()
    if not env_file:
      print("No environment selected.")
      exit(0)
    src = f'.env.{env_file}'
    if not os.path.exists(src):
      print(f"File {src} does not exist.")
      exit(1)
    if os.path.exists('.env'):
      os.remove('.env')
    print(f"Changing environment to: {env_file}")
    with open(src, 'r') as fsrc, open('.env', 'w') as fdst:
      fdst.write(fsrc.read())

# Configures the local environment for the project
[working-directory: 'backend']
configure:
    #/usr/bin/env bash

    # Use `.env.example` to create `.env`
    if [ ! -f .env ]; then echo ".env file not found. Creating it from .env.example..."; cp .env.example .env; fi

    # Update `.env` replacing the following with real values:
    # <postgres_pwd>
    # <random_string_goes_here>
    # <superuser_password>
    @just replace-token ".env" "postgres_pwd" $(openssl rand -hex 8)
    @just replace-token ".env" "random_string_goes_here" $(openssl rand -hex 16)
    @just replace-token ".env" "superuser_password" "admin123"

    # Create a local `.env.local` file if it doesn't exist
    if [ ! -f .env.local ]; then cp .env .env.local; fi

    # Start the backend services for the first time
    @echo "Starting backend services for the first time..."

    # Build and start the Docker containers
    $DOCKER_COMPOSE up --detach --build

    # Run migrations and create the superuser
    @just migrate
    @just seed-backend
    @just configure-superuser

    # Stop services to ensure they are ready for the next start
    @just stop
    @echo "Backend services started and database initialized; check the .env file for superuser credentials."
    @echo "To start the backend services, run 'just run-backend'."

# Generate a token to put into a file
[private]
replace-token filename token replace:
    #/usr/bin/env bash
    if ! grep -q "<{{token}}>" "{{filename}}"; then exit 0; fi
    perl -i -pe 's|<{{token}}>|{{replace}}|g' "{{filename}}"

# Stops backend services without removing volumes or orphaned containers
[working-directory: 'backend']
stop-backend:
    #/usr/bin/env bash
    @echo "Stopping services..."
    $DOCKER_COMPOSE stop
    @echo "Backend stopped."

# Stops backend services and removes all artifacts including volumes and orphaned containers
[working-directory: 'backend']
clean-backend:
    #/usr/bin/env bash
    @echo "Cleaning up backend services..."
    @just stop || echo "No services to stop."
    $DOCKER_COMPOSE down --volumes --remove-orphans
    docker system prune --force --volumes
    docker volume prune --force
    docker network prune --force
    docker container prune --force
    docker image prune --force

    rm -rf venv
    rm -rf .env
    rm -rf .pytest_cache
    rm -rf .mypy_cache
    rm -rf __pycache__
    rm -rf .coverage
    rm -rf .tox

    @echo "Cleanup complete."

# Seed the database with initial data; this is a placeholder for actual seeding logic
[working-directory: 'backend']
seed-backend:
    #/usr/bin/env bash
    @echo "Seeding the database with sample data (Companies, Clients, Users, Certificates)..."
    $DOCKER_COMPOSE exec web python3 manage.py seed_test_data
    @echo "Database seeding complete."

# Create a superuser for the Django admin interface; credentials are taken from environment variables in .env
[working-directory: 'backend']
configure-superuser:
    #/usr/bin/env bash
    @echo "Creating superuser, please ensure you enter password: ${DJANGO_SUPERUSER_PASSWORD} when prompted..."
    $DOCKER_COMPOSE exec web python3 manage.py createsuperuser --username "${DJANGO_SUPERUSER_USERNAME}" --email "${DJANGO_SUPERUSER_EMAIL}"
    @echo "Superuser created."

# Regenerate Pipfile.lock inside a Python container
[working-directory: 'backend']
lock-backend python-version:
    #/usr/bin/env bash
    set -euo pipefail
    echo "Locking backend dependencies with Python {{python-version}} in Docker..."
    docker run --rm \
      -v "$PWD":/app \
      -w /app \
      python:{{python-version}} \
      bash -lc "python --version && pip install -q pipenv && pipenv lock --clear"
    echo "Generated Pipfile.lock for Python {{python-version}}."
