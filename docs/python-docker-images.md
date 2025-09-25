# Python Docker Images Build

This repository includes a workflow to build Docker images based on the `xperts-python-slim` Dockerfile for multiple Python versions.

## How to trigger the build

1. Go to the repository's Actions tab on GitHub
2. Select the "Build Python Docker Images" workflow
3. Click "Run workflow"
4. Choose whether to push images to the registry (default: true)
5. Click "Run workflow" to start the build

## What gets built

The workflow builds 6 Docker images for Python versions:
- 3.8
- 3.9
- 3.10
- 3.11
- 3.12
- 3.13

Each image is based on the `images/xperts-python-slim/Dockerfile` and uses the `PY_VER` build argument to specify the Python version.

## Where images are published

Images are published to GitHub Container Registry (ghcr.io) under this repository:
```
ghcr.io/morton-xperts/dev-helpers/xperts-python-slim:3.8
ghcr.io/morton-xperts/dev-helpers/xperts-python-slim:3.9
ghcr.io/morton-xperts/dev-helpers/xperts-python-slim:3.10
ghcr.io/morton-xperts/dev-helpers/xperts-python-slim:3.11
ghcr.io/morton-xperts/dev-helpers/xperts-python-slim:3.12
ghcr.io/morton-xperts/dev-helpers/xperts-python-slim:3.13
```

## Using the images

You can pull and use these images in your projects:

```bash
docker pull ghcr.io/morton-xperts/dev-helpers/xperts-python-slim:3.11
```

Or in a Dockerfile:
```dockerfile
FROM ghcr.io/morton-xperts/dev-helpers/xperts-python-slim:3.11
```