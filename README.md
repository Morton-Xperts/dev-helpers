# Xperts Dev Helpers

Reusable developer helpers for local automation, task running, and CI versioning. This repo provides Justfile-style 
recipes, simple scripts, and GitHub Actions to streamline multi-stack projects.  The intention of this repository is to
serve as a source for CI and toolchain helpers for both local development and GitHub workflows.  You should include this
repository in CI pipelines and/or as a git submodule in your projects to leverage the provided tools.  For more on 
submodules as a concept, go [here](https://git-scm.com/book/en/v2/Git-Tools-Submodules) or [here](https://gist.github.com/gitaarik/8735255).

## Setting Up the Submodule

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

## CI & Versioning
Commits on `main` trigger the Build workflow which increments the package version, tags a release, and pushes changes. 
The bump level is inferred from the commit message prefix:
- `major:` or `refactor:` → major
- `minor:` or `feat:` → minor
- otherwise → patch

## Docs
- iOS build configuration and workflows: see `docs/ios-build.md`.
- Android build configuration and workflows: see `docs/android-build.md`.

## Contributing
- Follow the style enforced by Prettier/ESLint.
- Keep recipes concise and cross-platform where possible; add domain-specific steps under the relevant `recipes/*.just` file.
- For new tasks, prefer adding a `recipes/<domain>.just` entry and referencing existing helpers.
