# Migration from Crowdbotics to Xperts

If you're considering migrating your project from Crowdbotics to Xperts, this guide will help you understand the steps 
involved in the process. This repo offers a robust platform with a variety of features that can enhance your project's 
development and deployment experience.

## Implement Main Branch and Switch to Trunk-Based Development
To preserve the current state of master, I will create a new branch called main. This branch will serve as the landing 
zone for all consolidation work as we transition toward trunk-based development.
- Branch from master → main.
- Make main the active working branch going forward.
- Preserve master in its current state for historical reference.
- Use main as the baseline for future reconciliation, build restoration, and environment alignment efforts.

## Configure Repository Settings
Update repository settings to enforce a clean, consistent pull request and branch workflow:
- Squash merging enabled: All commits from a PR are squashed into a single commit for a clean history.
- Merge commits disabled: Prevents noisy merge commits from cluttering trunk.
- Rebase merging disabled: Avoids accidental history rewrites and complexity.
- Default commit message: Uses pull request title for clarity.
- Update suggestions enabled: Contributors are prompted to sync their branch with base before merging.
- Auto-merge allowed: PRs can merge automatically once all required checks and reviews pass.
- Automatic branch deletion enabled: Head branches are deleted after merge to keep the repo clean.

This configuration aligns with trunk-based development practices by ensuring a linear history, reducing integration 
friction, and automatically cleaning up stale branches.

## Protect main and Enforce Linear History
Enable branch protection on main.
- Require PRs, 1+ code review, and all status checks to pass.
- Disallow direct pushes; require up-to-date branch before merge.
- Require linear history (compatible with squash only).
- Require signed commits (if org allows).
- Dismiss stale reviews on new commits.
- Restrict who can push/merge (maintainers only).

## Integrate Xperts Dev Helpers

### Setting Up the Submodule

If you are using HTTPS:
```bash
git submodule add https://github.com/Morton-Xperts/dev-helpers.git .xperts/dev-helpers
git submodule sync --recursive
git submodule update --init --recursive
```

If you are using SSH:
```bash
git submodule add git@github.com:Morton-Xperts/dev-helpers.git .xperts/dev-helpers
git submodule sync --recursive
git submodule update --init --recursive
```

### Integrating Recipes
Set up your root justfile with the following contents to include the Xperts recipes:

```just
#!/usr/bin/env just

import './.xperts/dev-helpers/recipes/index.just'

@default:
    @echo "Available recipes:"
    @just --choose

```

### CI & Versioning
Ensure you have properly configured remaining files by running the following recipe: `just init-from-crowdbotics`

## Complete Environment Rationalization
Rationalize and consolidate environments to streamline development and deployment processes:
- Introduce .env.example at repo root and per-service as needed.
- Replace hardcoded env vars across code with config loader.
- Local dev: .env files loaded; CI: uses secrets manager/CI secrets.
- Docs: how to run locally with .env and compose.
- Secret scanning enabled (e.g., GitHub secret scanning) and passing.

## Pin Dependencies and Ensure Reproducible Builds
- Lockfiles present and committed (npm/yarn/pnpm, CocoaPods, Gradle).
- Toolchain pinned: Node, Java, Ruby/CocoaPods, Python (via .nvmrc, asdf or .tool-versions, pyproject/requirements.txt).
- CI uses the pinned versions.
- Build succeeds locally with a single make bootstrap (or task).

## Establish Minimal Green Builds for Various Artifacts

### Backend


### Frontend


### Android


### iOS

## Publish Build Artifacts from CI
- iOS: Export .ipa and upload to PR artifacts.
- Android: Export .apk and upload to PR artifacts.
- Web: Upload static bundle artifact.
- Backend: Push Docker image to internal registry on main.
- All artifacts retained for at least 30 days.

