# iOS Build Configuration (ios.json)

The `ios-build` Just recipe reads its parameters from a JSON file at the repo root named `ios.json`. This lets you customize the iOS build without editing code.

## Requirements
- `jq` must be installed (used to parse `ios.json`).
- Xcode and CocoaPods installed; the `ios/` directory contains your Xcode workspace and `ExportOptions.plist`.

## Supported Fields
All fields are optional; sensible defaults apply if a field is missing. Keys are case-sensitive.

- `nodeVersion`: Node.js version for CI setup (e.g., `18`).
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
- `appStoreConnect`: Object containing optional upload credentials. Provide either `username`/`password` (legacy login) or `issuerId`/`keyId`/`privateKeyP8` (API key workflow). See https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/
  
### Signing (Sensitive)
- `certificateBase64`: Base64-encoded .p12 signing certificate.
- `certificatePath`: Filesystem path to the `.p12` certificate (alternative to `certificateBase64`).
- `p12Password`: Password for the .p12 certificate.
- `provisioningProfilesBase64`: Base64-encoded tar.gz of provisioning profiles.
- `provisioningProfilesPath`: Filesystem path to a `.tar.gz` containing provisioning profiles (alternative to `provisioningProfilesBase64`).
- `keychainPassword`: Temporary keychain password used during codesigning.

Security note: Avoid committing real secrets to version control. Prefer supplying these via Action inputs or generating 
`ios.json` at runtime using GitHub Secrets.

## Example ios.json
```
{
  "nodeVersion": "18",
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
  "appStoreConnect": {
    "username": "",
    "password": "",
    "issuerId": "",
    "keyId": "",
    "privateKeyP8": "-----BEGIN PRIVATE KEY-----\\n...\\n-----END PRIVATE KEY-----"
  },
  
  "certificateBase64": "",
  "certificatePath": "",
  "p12Password": "",
  "provisioningProfilesBase64": "",
  "provisioningProfilesPath": "",
  "keychainPassword": ""
}
```

## Defaults (if ios.json is absent)
- `workspace`: `my_app.xcworkspace`
- `scheme`: `Production`
- `targetSdk`: `iphonesimulator16.4`
- `releaseBuildDir`: `/tmp/MyApp/build`
- `archivePath`: `build/Archive/<scheme>.xcarchive`
- `exportOptionsPlist`: `ExportOptions.plist`
- `exportPath`: `build/App`

## Usage
Run from the repository root:
```
just ios-build env=prd
```
The recipe will:
- Install CocoaPods (`pod install`) in the `ios/` directory.
- Build via `xcodebuild` using values from `ios.json`.
- Archive and export the app to the configured `exportPath`.

## GitHub Actions Integration
- `recipes/install-signing`: run `just install-signing` locally to create the signing keychain and install provisioning profiles using `ios.json`. Supply overrides via environment variables (e.g., `IOS_SIGNING_CERT_BASE64`) or by passing recipe arguments.
- `actions/ios-signing` installs the signing certificate and provisioning profiles defined in `ios.json`. It can also accept overrides through action inputs, making it easy to feed GitHub Secrets at runtime.
- `actions/ios-build` reads Node.js version, environment, artifact names, and output locations from `ios.json` and uploads them automatically. The action delegates building and signing to the `ios-build` recipe. Keep `ios/ExportOptions.plist` in place.
- `actions/ios-upload` resolves the artifact path from `ios.json` and auto-detects the IPA filename when possible (or falls back to `applicationName.ipa`). Supply either `appStoreConnect.username/password` or API key credentials under `appStoreConnect`.
  - It also reads `artifact-name` and App Store Connect credentials from `ios.json` if not provided as inputs.

### Action Inputs (ios-build)
- `env`: Overrides environment (`dev` or `prd`).
