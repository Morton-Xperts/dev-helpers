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
    @just -f ../justfile make-migrations {{app}}
    @echo "Running migrations..."
    $DOCKER_COMPOSE exec web python3 manage.py migrate {{app}}

# Show migrations status
[working-directory: 'backend']
show-migrations app="":
    @echo "Showing migrations..."
    $DOCKER_COMPOSE exec web python3 manage.py showmigrations {{app}}

# Resync migrations by faking a zero state and reapplying migrations
[working-directory: 'backend']
resync-migrations app="" rev="zero":
    @echo "Resyncing migrations..."
    $DOCKER_COMPOSE exec web python3 manage.py migrate --fake {{app}} {{rev}}
    @just -f ../justfile migrate "{{app}}"

# Migrate the database schema to the latest version
[working-directory: 'backend']
make-migrations app="":
    @echo "Making migrations..."
    $DOCKER_COMPOSE exec web python3 manage.py makemigrations {{app}}

# Merge divergent migrations
[working-directory: 'backend']
merge-migrations:
    @echo "Merging migrations..."
    $DOCKER_COMPOSE exec web python3 manage.py makemigrations --merge

# Migrate the database schema to the latest version and rebuild the backend
[working-directory: 'backend']
migrate-and-rebuild app="":
    @just -f ../justfile migrate "{{app}}"
    @just -f ../justfile rebuild-backend

# Run the application in a Docker container
[working-directory: 'backend']
run-backend:
    #/usr/bin/env bash
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

# Create a Python virtual environment within the backend directory
[working-directory: 'backend']
create-venv name=".venv":
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -d "{{name}}" ]; then
      echo "Virtual environment '{{name}}' already exists at $(pwd)/{{name}}"
      exit 0
    fi

    if ! command -v python3 >/dev/null 2>&1; then
      echo "python3 is required but was not found in PATH" >&2
      exit 1
    fi

    echo "Creating virtual environment '{{name}}' in $(pwd)"
    python3 -m venv "{{name}}"

    VENV_PY="$(pwd)/{{name}}/bin/python"

    echo "Upgrading pip in the virtual environment..."
    "$VENV_PY" -m pip install --upgrade pip setuptools wheel >/dev/null

    if [ -f "requirements.txt" ]; then
      echo "Installing dependencies from requirements.txt..."
      "$VENV_PY" -m pip install -r requirements.txt
    elif [ -f "requirements/local.txt" ]; then
      echo "Installing dependencies from requirements/local.txt..."
      "$VENV_PY" -m pip install -r requirements/local.txt
    elif [ -f "Pipfile.lock" ]; then
      echo "Installing dependencies from Pipfile.lock..."
      "$VENV_PY" <<'PY'
    import json
    import subprocess
    import sys

    lock_path = 'Pipfile.lock'
    with open(lock_path) as fh:
        data = json.load(fh)

    packages = []
    for section in ('default', 'develop'):
        for name, meta in data.get(section, {}).items():
            extras = meta.get('extras')
            markers = meta.get('markers')
            version = meta.get('version', '')
            pkg_name = name
            if extras:
                pkg_name += '[' + ','.join(extras) + ']'
            spec = pkg_name + version
            if markers:
                spec += f"; {markers}"
            packages.append(spec)

    if packages:
        subprocess.check_call([sys.executable, '-m', 'pip', 'install', *packages])
    else:
        print('No packages found in Pipfile.lock; skipping install')
    PY
    else
      echo "No dependency manifest found. Virtual environment created without packages."
    fi

    echo "Virtual environment created. Activate it with 'source backend/{{name}}/bin/activate'"

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

# Tail logs from the web service container
[working-directory: 'backend']
tail-web-logs:
    @echo "Streaming logs from the web container..."
    $DOCKER_COMPOSE logs -f web

# Stop all running Docker containers
stop-all-containers:
    #!/usr/bin/env bash
    set -euo pipefail
    running=$(docker ps -q)
    if [ -z "$running" ]; then
      echo "No running containers."
      exit 0
    fi
    echo "Stopping all running containers..."
    docker stop $running

# Show running Docker containers
list-running-containers:
    @docker ps

# Stop a running Docker container selected via fzf
stop-container:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v fzf >/dev/null 2>&1; then
      echo "fzf is required but not installed." >&2
      exit 1
    fi
    # Escape Go template braces so `just` doesn't try to interpolate them
    selection=$(docker ps --format "{{'{{'}}.ID{{'}}'}}\t{{'{{'}}.Names{{'}}'}}\t{{'{{'}}.Image{{'}}'}}\t{{'{{'}}.Status{{'}}'}}" | fzf --prompt="Select container to stop: " || true)
    if [ -z "$selection" ]; then
      echo "No container selected."
      exit 0
    fi
    container_id=$(echo "$selection" | awk '{print $1}')
    echo "Stopping container $container_id..."
    docker stop "$container_id"

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

[private]
set-env env_suffix:
    #/usr/bin/env bash
    if [ -f backend/.env ]; then rm backend/.env; fi
    if [ ! -f backend/.env.{{env_suffix}} ]; then echo "backend/.env.{{env_suffix}} file not found!"; exit 1; fi
    cp backend/.env.{{env_suffix}} backend/.env
    @echo "Environment set to {{env_suffix}}"

# Configures the local environment for the project
[working-directory: 'backend']
configure-local superuser_password:
    #/usr/bin/env bash
    if [ -f .env.local ]; then echo ".env.local file already exists. Please delete it if you want to reconfigure."; exit 0; fi

    # Use `.env.example` to create `.env`
    if [ ! -f .env.local ]; then echo ".env file not found. Creating it from .env.example..."; cp .env.example .env.local; fi

    # Update `.env` replacing the following with real values:
    # <postgres_pwd>
    # <random_string_goes_here>
    # <superuser_password>
    @just -f ../justfile replace-token "backend/.env.local" "postgres_pwd" $(openssl rand -hex 8)
    @just -f ../justfile replace-token "backend/.env.local" "random_string_goes_here" $(openssl rand -hex 16)
    @just -f ../justfile replace-token "backend/.env.local" "superuser_password" "{{superuser_password}}"

# Configures the local environment for the project
[working-directory: 'backend']
configure superuser_password: (configure-local "{{superuser_password}}") (set-env "local")
    #/usr/bin/env bash

    # Start the backend services for the first time
    @echo "Starting backend services for the first time..."

    # Build and start the Docker containers
    $DOCKER_COMPOSE up --detach --build

    # Wait for the database to be ready
    @echo "Waiting for PostgreSQL to be ready..."
    @bash -c 'for i in {1..30}; do \
        if $DOCKER_COMPOSE exec -T postgres pg_isready -U postgres > /dev/null 2>&1; then \
            echo "Database is ready."; \
            exit 0; \
        fi; \
        echo "Waiting for database..."; \
        sleep 2; \
    done; \
    echo "Database failed to start in time."; \
    exit 1'

    # Run migrations and create the superuser
    @just -f ../justfile migrate
    @just -f ../justfile seed-backend || echo "Could not seed backend; continuing..."
    @just -f ../justfile configure-superuser

    # Stop services to ensure they are ready for the next start
    @just -f ../justfile stop-backend
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
    @just -f ../justfile stop-backend || echo "No services to stop."
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

# Create a superuser for the Django admin interface; credentials are taken from environment variables in .env
[working-directory: 'backend']
create-superuser username email:
    @echo "Creating superuser..."
    $DOCKER_COMPOSE exec web python3 manage.py createsuperuser --username "{{username}}" --email "{{email}}"
    @echo "Superuser created."

# Regenerate Pipfile.lock inside a Python container
[working-directory: 'backend']
lock-backend python-version="":
    #!/usr/bin/env bash
    set -euo pipefail

    PY_VERSION="{{python-version}}"
    if [ -z "$PY_VERSION" ]; then
    if [ ! -f .python-version ]; then
    echo "Error: Python version not provided and backend/.python-version not found." >&2
    exit 1
    fi
    PY_VERSION=$(tr -d ' \t\r\n' < .python-version)
    if [ -z "$PY_VERSION" ]; then
    echo "Error: backend/.python-version is empty." >&2
    exit 1
    fi
    fi

    echo "Locking backend dependencies with Python $PY_VERSION in Docker..."
    TMP_VENV_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t pipenv-lock)
    cleanup() {
      rm -rf "$TMP_VENV_DIR"
    }
    trap cleanup EXIT

    docker run --rm \
      -v "$PWD":/app \
      -v "$TMP_VENV_DIR":/app/.venv \
      -w /app \
      python:"$PY_VERSION" \
      bash -lc "python --version && pip install -q pipenv && PIPENV_VENV_IN_PROJECT=1 pipenv lock --clear"
    echo "Generated Pipfile.lock for Python $PY_VERSION."

# Collect static files into the STATIC_ROOT directory
[working-directory: 'backend']
collect-static:
    #/usr/bin/env bash
    set -euo pipefail
    echo "Collecting static files..."
    $DOCKER_COMPOSE exec web python3 manage.py collectstatic --noinput
    echo "Static files collected."

# Run a query against the database
[working-directory: 'backend']
query sql:
    #/usr/bin/env bash
    set -euo pipefail
    echo "Running SQL query..."
    $DOCKER_COMPOSE exec postgres psql -U postgres -d postgres -c "{{sql}}"
    echo "Query executed."

set-db-timezone timezone:
    @just query "ALTER SYSTEM SET timezone TO '{{timezone}}'; SELECT pg_reload_conf();"
    @just query "SHOW TIME ZONE;"
    @just query "SELECT EXTRACT(TIMEZONE FROM now());"

[working-directory: 'backend']
test-backend target="":
    #!/usr/bin/env bash
    set -euo pipefail
    echo 'Running backend tests...'
    $DOCKER_COMPOSE exec web python3 manage.py collectstatic --noinput
    if [ -n "{{target}}" ]; then
      $DOCKER_COMPOSE exec web python3 manage.py test {{target}}
    else
      $DOCKER_COMPOSE exec web python3 manage.py test
    fi
