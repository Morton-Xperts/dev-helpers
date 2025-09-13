# iOS Build Configuration (ios.json)

`scripts/build-ios.sh` reads its parameters from a JSON file at the repo root named `ios.json`. This lets you customize the iOS build without editing the script.

## Requirements
- `jq` must be installed (used to parse `ios.json`).
- Xcode and CocoaPods installed; the `ios/` directory contains your Xcode workspace and `ExportOptions.plist`.

## Supported Fields
All fields are optional; sensible defaults apply if a field is missing. Keys are case-sensitive.

- `nodeVersion`: Node.js version for CI setup (e.g., `18`).
- `env`: Logical app environment used to generate `env.js` (`dev` or `prd`).
- `buildScript`: Path to the build script (default `scripts/build-ios.sh`).
- `workspace`: Xcode workspace filename (e.g., `MyApp.xcworkspace`).
- `scheme`: Xcode scheme to build (e.g., `Production`).
- `targetSdk`: SDK for the initial build (e.g., `iphonesimulator` or `iphoneos`).
- `applicationName`: App display name (informational in the script).
- `developerName`: Signing identity label (informational in the script).
- `releaseBuildDir`: Output directory for intermediate build products.
- `archivePath`: Full path (relative to `ios/`) to the `.xcarchive`.
- `exportOptionsPlist`: Filename of the export options plist in `ios/`.
- `exportPath`: Output directory for the exported IPA (relative to `ios/`).
- `archiveArtifactName`: Name of the uploaded archive artifact (default `iOS-archive`).
- `appArtifactName`: Name of the uploaded app artifact (default `iOS-app`).
  
### App Store Connect (Upload)
- `appStoreConnectUsername`: Apple ID used for App Store Connect.
- `appStoreConnectPassword`: App-specific password for App Store Connect.
  
### Signing (Sensitive)
- `certificateBase64`: Base64-encoded .p12 signing certificate.
- `p12Password`: Password for the .p12 certificate.
- `provisioningProfilesBase64`: Base64-encoded tar.gz of provisioning profiles.
- `keychainPassword`: Temporary keychain password used during codesigning.

Security note: Avoid committing real secrets to version control. Prefer supplying these via Action inputs or generating 
`ios.json` at runtime using GitHub Secrets.

## Example ios.json
```
{
  "nodeVersion": "18",
  "env": "prd",
  "buildScript": "scripts/build-ios.sh",
  "workspace": "MyApp.xcworkspace",
  "scheme": "Production",
  "targetSdk": "iphonesimulator",
  "applicationName": "MyApp",
  "developerName": "iPhone Distribution: Your Company, Inc. (TEAMID)",
  "releaseBuildDir": "build/Release",
  "archivePath": "build/Archive/Production.xcarchive",
  "exportOptionsPlist": "ExportOptions.plist",
  "exportPath": "build/App",
  "archiveArtifactName": "iOS-archive",
  "appArtifactName": "iOS-app",
  
  "certificateBase64": "",
  "p12Password": "",
  "provisioningProfilesBase64": "",
  "keychainPassword": ""
}
```

## Defaults (if ios.json is absent)
- `workspace`: `polished_truth_42233.xcworkspace`
- `scheme`: `Production`
- `targetSdk`: `iphonesimulator16.4`
- `releaseBuildDir`: `/tmp/NaborApp/build`
- `archivePath`: `build/Archive/<scheme>.xcarchive`
- `exportOptionsPlist`: `ExportOptions.plist`
- `exportPath`: `build/App`

## Usage
Run from the repository root:
```
sh scripts/build-ios.sh
```
The script will:
- Install CocoaPods (`pod install`) in the `ios/` directory.
- Build via `xcodebuild` using values from `ios.json`.
- Archive and export the app to the configured `exportPath`.

## GitHub Actions Integration
- `actions/ios-build` reads Node.js version, environment, script path, artifact names, and output locations from `ios.json` and uploads them automatically. Keep `ios/ExportOptions.plist` in place.
- `actions/ios-upload` resolves the artifact path from `ios.json` and auto-detects the IPA filename when possible (or falls back to `applicationName.ipa`). You only need to provide `username` and `password`.
  - It also reads `artifact-name`, `username`, and `password` from `ios.json` if not provided as inputs.
