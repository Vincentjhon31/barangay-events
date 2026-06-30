# Barangay Events

A Flutter calendar app for barangay event scheduling and sharing.

## Local Build

```powershell
flutter pub get
flutter test
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

## Update-Safe Releases

The app checks the latest GitHub Release for this repository and shows an update prompt when a newer APK is available.

Android can update the app without uninstalling only when every APK has:

- the same `applicationId`
- a higher `version` / build number in `pubspec.yaml`
- the same signing key

For GitHub Actions releases, add these repository secrets in **Settings > Secrets and variables > Actions**:

- `KEYSTORE_FILE`: base64-encoded contents of your `.jks` keystore
- `KEYSTORE_PASSWORD`: keystore password
- `KEY_ALIAS`: key alias
- `KEY_PASSWORD`: key password

After the secrets are set, each push to `main` or `master` builds a signed APK and creates a GitHub Release tagged from `pubspec.yaml`.
