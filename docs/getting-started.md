# Getting Started

This guide helps you run the stack locally using the provided Just recipes, Docker services, and Yarn workflows. It reflects the repository conventions used here.


## Todos:
- [ ] add note regarding updating the pipfile in backend



## Prerequisites
- Docker and Docker Compose
- Node.js 18 and Yarn (via `nvm` recommended)
- Just command runner (`brew install just` on macOS)
- Optional: Xcode (iOS), Android SDK (Android)

## Project Layout
- `backend/`: Django 2.2 API, admin, migrations. Environment via `backend/.env` and Docker Compose.
- Root app: React Native + Web. Key dirs: `components/`, `screens/`, `modules/`, `store/`, `public/`.
- Automation: `justfile` and `recipes/*.just` recipes. CI/scripts in `scripts/` and `.github/`.
- Tests: JS tests in `__tests__/`. Django tests under `backend/<app>/tests/`.

## First-Time Setup
1) Configure backend env and bootstrap containers
- From the repo root: `just configure`
  - Copies `backend/.env.example` to `backend/.env` (with tokens filled), builds containers, runs migrations, seeds data, and creates a superuser.

2) Start backend services
- `just run-backend`
- Admin: `http://localhost:8000/admin/` (or `just open-admin`)
- API docs: `http://localhost:8000/api-docs/` (or `just open-api-docs`)

3) Apply schema changes later
- Make migrations: `just make-migrations` or `just make-migrations app=<app>`
- Apply: `just migrate` or `just migrate app=<app>`
- Rebuild image after migrations if needed: `just migrate-and-rebuild`

4) Create or update admin user
- Interactive: `just create-superuser`
- From env vars: `just configure-superuser` (uses values in `backend/.env`)

## Frontend
- Web dev server: `just run-web` (hot reload on port 8080 by default)
- React Native:
  - iOS: `just run-ios`
  - Android: `just run-android`
- Production-like web in `backend/web_app/`:
  - `just start-frontend` (installs, builds, and starts `backend/web_app/` with `REACT_APP_API_BASE_URL=http://localhost:8000/api`)

## Guardrails
- Do not edit `backend/**/migrations/*.py` by hand. Use `just make-migrations` and `just migrate`. If a manual migration edit is absolutely required, get explicit approval first.
- Prefer extending existing models; add new models within an existing app when domain-appropriate.
- Frontend: use functional components and hooks; prefer TypeScript once enabled.

## Testing
- JavaScript: place tests in `__tests__/` and run with your package script, e.g. `yarn test`.
- Django: add tests under `backend/<app>/tests/` and run via Docker: `docker compose -f backend/docker-compose.yml -f backend/docker-compose.override.yml exec web python manage.py test`

## Common Tasks (Quick Reference)
- Start backend: `just run-backend`
- Open admin/API docs: `just open-admin` / `just open-api-docs`
- Migrations: `just make-migrations [app]` then `just migrate [app]`
- Rebuild backend: `just rebuild-backend` or `just migrate-and-rebuild`
- Start web dev: `just run-web`
- Start RN: `just run-react-native` (or platform-specific `just run-ios` / `just run-android`)

## Configuration & Secrets
- Store local secrets in `backend/.env`. Do not commit secrets; use `backend/.env.example` as a template.
- Local superuser credentials are controlled by env vars in `backend/.env` when using `just configure-superuser`.

## Troubleshooting
- Backend won’t start: run `just rebuild-backend` to force a clean build, or `just clean-backend` to reset containers and volumes, then `just run-backend`.
- DB schema drift: re-run `just migrate`. If migrations pile up, consider `just squish-migrations` to squash within an app (review the generated file before committing).
- Frontend API URL: ensure `REACT_APP_API_BASE_URL` points to `http://localhost:8000/api` for local dev.
