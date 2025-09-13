# Android Build and Upload (android.json)

`android.json` centralizes configuration for Android build and upload actions. For upload, only the Play service account JSON and package name are inputs; everything else is read from `android.json`.

## Requirements
- `jq` available in the runner to parse `android.json`.
- Android SDK/NDK via `android-actions/setup-android` and JDK (already handled by the action).

## Supported Fields
- `nodeVersion`: Node.js version for the build job (default `18`).

Build outputs (consumed by `actions/android-build` uploads):
- `aabPath`: Path to the generated AAB.
- `manifestsPath`: Path to merged manifests directory.
- `debugSymbolsPath`: Path to merged native libs/debug symbols directory.
- `appArtifactName`: Name of the app artifact uploaded by the build action.
- `manifestsArtifactName`: Name of the merged manifests artifact.
- `debugSymbolsArtifactName`: Name of the debug symbols artifact.

Upload inputs (consumed by `actions/android-upload`):
- `serviceAccountJson`: Google Play service account JSON (plaintext). Sensitive.
- `packageName`: Application ID (e.g., `com.example.app`).
- `track`: Play track (e.g., `internal`, `alpha`, `beta`, `production`).
- `status`: Release status (e.g., `completed`).
- `inAppUpdatePriority`: Priority as a string (e.g., `2`).
- `whatsNewDirectory`: Directory containing localized "whats new" files.
- `changesNotSentForReview`: `true`/`false`.
- `appArtifactPath`: Directory where the app artifact is downloaded in the upload job.
- `uploadDebugSymbolsPath`: Directory where debug symbols are downloaded in the upload job.
- `releaseFile`: Path to the AAB to upload.
- `releaseName`: Optional name of the release.

## Example android.json
```
{
  "nodeVersion": "18",

  "aabPath": "android/app/build/outputs/bundle/release/app-release.aab",
  "manifestsPath": "android/app/build/intermediates/merged_manifests",
  "debugSymbolsPath": "android/app/build/intermediates/merged_native_libs/release/out/lib",
  "appArtifactName": "android",
  "manifestsArtifactName": "android-merged-manifests",
  "debugSymbolsArtifactName": "android-debug-symbols",

  "serviceAccountJson": "",
  "packageName": "",
  "track": "internal",
  "status": "completed",
  "inAppUpdatePriority": "2",
  "whatsNewDirectory": "whats-new",
  "changesNotSentForReview": "false",
  "appArtifactPath": "android/_artifacts",
  "uploadDebugSymbolsPath": "android/_debugSymbols",
  "releaseFile": "android/_artifacts/app-release.aab",
  "releaseName": ""
}
```

Security note: Do not commit real secrets (e.g., `serviceAccountJson`) to source control. Provide them as Action inputs via GitHub Secrets or generate `android.json` at runtime in the workflow.

## Usage
- Build: use `actions/android-build`. It reads environment, Node version, artifact names, and paths from `android.json` and uploads the configured artifacts.
- Upload: use `actions/android-upload`. It reads Play credentials, package name, track, and file paths from `android.json`. Only `service-account-json` and `package-name` are action inputs; all other settings come from `android.json`.

```
jobs:
  android-build:
    steps:
      - uses: actions/checkout@v4
      - uses: ./.xperts/dev-helpers/actions/android-build

  android-upload:
    needs: android-build
    steps:
      - uses: actions/checkout@v4
      - uses: ./.xperts/dev-helpers/actions/android-upload
        with:
          # Prefer to pass secrets via inputs from GitHub Secrets
          service-account-json: ${{ secrets.GOOGLE_PLAY_SA_JSON }}
          package-name: com.example.app
          # Only these two inputs exist; android.json fills everything else
```
