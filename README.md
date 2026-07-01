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

If the app is already installed from a different signing key, uninstall that copy once before installing the release-signed APK. After that, future releases can update normally as long as the signing key stays the same.

For GitHub Actions releases, add these repository secrets in **Settings > Secrets and variables > Actions**:

- `KEYSTORE_FILE`: base64-encoded contents of your `.jks` keystore
- `KEYSTORE_PASSWORD`: keystore password
- `KEY_ALIAS`: key alias
- `KEY_PASSWORD`: key password

After the secrets are set, each push to `main` or `master` builds a signed APK and creates a GitHub Release tagged from `pubspec.yaml`.

## Supabase Storage

The calendar now reads and writes shared events through Supabase. Run the SQL script in [supabase/barangay_events.sql](supabase/barangay_events.sql) in your Supabase SQL editor to create the `barangay_events` table and its basic policies.

The script also adds the table to `supabase_realtime`, so inserts and updates show up on every connected device without a manual refresh.

The app is initialized with this Supabase project:

- `https://xuxnoydakqembrytdbyz.supabase.co`
- public anon key from the setup request

If you want the backend to be private later, replace the permissive policies in the SQL file with auth-based policies.

## Supabase Auth

The app now starts with a login screen when the user is signed out. From there, users can either log in or create an account with Supabase Auth.

If you are testing locally, you can sign up with the email/password form in the app. If your Supabase project requires email confirmation, the sign-up flow will tell the user to confirm their email before logging in.
