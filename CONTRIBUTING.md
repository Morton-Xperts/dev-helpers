# Contributing to Xperts Dev Helpers

Thanks for helping improve the developer helpers that power our local automation and CI! This repo is consumed directly and via git submodules, so we prioritize backwards‑compatible changes and good docs.

## Ways to Contribute
- Recipes: Add or improve `recipes/*.just` tasks and `justfile` usage.
- Actions: Enhance composite GitHub Actions in `actions/*` and workflow glue in `.github/workflows/*`.
- Docs: Expand or clarify content in `docs/*` and `README.md`.
- Scripts: Improve cross‑platform helpers in `scripts/*` and small utilities in `resources/*`.

## Quick Start
- Install Just (macOS: `brew install just`, Linux: see https://github.com/casey/just). Run `just` to see available tasks.
- Optional toolchain: see `docs/getting-started.md` or run `yarn setup` (runs `scripts/setup.sh`, macOS‑oriented and installs many tools).
- Explore available automation in `recipes/index.just` and corresponding domain files.

## Development Workflow
- Create a feature branch from `main`.
- Make small, focused commits with clear messages (see Versioning below).
- Keep changes minimal and well‑scoped; update docs alongside code.
- Validate locally:
  - Recipes: run with `just <task>`.
  - Actions: sanity‑check structure and inputs; when possible, verify in a fork or with `act` locally.
  - Workflows: prefer testing in a branch with a temporary workflow if behavior changes.

## Commit Messages and CI Versioning
Commits that land on `main` trigger the Build workflow which bumps the package version, tags a release, and pushes changes. The bump level is inferred from the commit message prefix:
- `major:` or `refactor:` → major bump
- `minor:` or `feat:` → minor bump
- anything else → patch bump

Guidelines:
- Use one of the prefixes above at the beginning of your commit subject (e.g., `feat: add Android upload step`).
- If using squash merges, ensure the PR title carries the correct prefix — it becomes the squashed commit message.
- Do not manually bump versions in files; CI will update versions and create the release.

## Code Style
- Follow Prettier/ESLint conventions where applicable; prefer consistent formatting over personal style.
- Bash/zsh: aim for `set -euo pipefail` in scripts and `#!/usr/bin/env bash` shebangs where shell portability isn’t required.
- Python snippets for actions should be small, dependency‑free, and pinned to the runner’s default Python.
- Keep recipes concise; prefer composing existing tasks over duplicating logic.

## Recipes
- Add new domain files under `recipes/<domain>.just` and import them in `recipes/index.just`.
- Use clear target names (`build-android`, `ios-upload`) and add short `@echo` descriptions.
- Prefer parameters with sensible defaults (see `android.just build-android env="staging"`).
- Avoid hard‑coding secrets or environment paths; read from config files (e.g., `resources/*.json`) or env vars.

## GitHub Actions
- Composite actions live under `actions/<name>/action.yml`. Keep inputs explicit and validated.
- Favor shell and small Python blocks over external dependencies.
- Document inputs/outputs well in `action.yml` and ensure helpful error messages.
- When changing input names or semantics, treat as a breaking change (`major:`) and update all in‑repo usage and docs.

## Workflows
- Primary workflow: `.github/workflows/main.yml` handles versioning and release tagging.
- Keep workflows readable; group related steps and use action outputs rather than duplicating logic.
- When adding steps that write to the repo (e.g., generated files), ensure they are committed intentionally or ignored.

## Resources and Config
- Shared config is under `resources/` (e.g., `android.json`, `ios.json`) and may be consumed by recipes and actions.
- If you add new config keys, default them sensibly and avoid breaking consumers. Document keys in `docs/*`.

## Backwards Compatibility
This repository is commonly used as a submodule. Please:
- Avoid breaking public action inputs, outputs, and recipe names.
- Prefer additive changes; deprecate before removal where possible.
- For necessary breaking changes, clearly mark with a `major:` commit and update docs and migration notes.

## Pull Requests
- Include a concise description, the motivation, and any doc links.
- Checklist:
  - [ ] Commit/PR title uses the correct prefix for release bump.
  - [ ] Recipes import added to `recipes/index.just` (if applicable).
  - [ ] Docs updated (`README.md` or `docs/*`).
  - [ ] CI passes on the branch.
- Target `main`. Use squash merge unless there’s a reason to preserve individual commits.

## Reporting Issues & Requests
- Use clear, reproducible steps and include environment details where relevant.
- If the issue affects CI versioning or releases, please include a link to the failing run and the exact commit message used.

## Local Environment Tips
- Node version: prefer using `.nvmrc` when present; otherwise follow the version used by CI (`vars.NODE_VERSION`).
- Android/iOS helpers require platform SDKs; see `docs/android-build.md` and `docs/ios-build.md`.
- Many tasks expect macOS paths and tools; contributions improving cross‑platform compatibility are welcome.

## License
Contributions are made under the repository’s license (see `LICENSE`).

