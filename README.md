# Barangay Events

A Flutter calendar app for barangay event scheduling and sharing.

## Download the App

**Permanent download link (always the latest version):**

https://vincentjhon31.github.io/barangay-events/

Or scan this QR code — it points to the same permanent link, so it never needs
to be reprinted when a new version is released:

![Download e-Calendar](docs/download-qr.png)

The link is a small GitHub Pages redirect ([docs/index.html](docs/index.html))
that always forwards to the newest release's **versioned** APK
(`e-calendar-1.3.0.apk`, `e-calendar-1.4.0.apk`, …), so downloaded files show
which version they are instead of all sharing one name. GitHub Pages must stay
enabled (Settings → Pages → Deploy from branch `main`, folder `/docs`).

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

## Push Notifications

New public and group events push a real-time notification (Android only) via Firebase Cloud Messaging. The app degrades gracefully without any of this configured — it just won't send/show pushes. One-time setup:

1. **Firebase Console** → create a project → add an Android app with package name **exactly** `com.example.barangay_events` (the `applicationId` in `android/app/build.gradle.kts`) → download `google-services.json` → save it as `android/app/google-services.json`. It's safe to commit (not a secret — it ships inside every APK anyway); the build automatically wires up the Firebase Gradle plugin once this file is present, and skips it otherwise.
2. **Firebase Console** → Project Settings → Service accounts → *Generate new private key* → save the downloaded JSON.
3. Set it as a secret for the Edge Function: `supabase secrets set FCM_SERVICE_ACCOUNT_JSON='<paste the JSON>'`. Optionally also set a shared secret for the webhook itself: `supabase secrets set WEBHOOK_SECRET='<any random string>'`.
4. Deploy the function: `supabase functions deploy send-event-notification` (from the repo root; needs the Supabase CLI logged into this project).
5. **Supabase Dashboard** → Database → Webhooks → *Create a new webhook*:
   - Table: `barangay_events`, Event: `INSERT`, Type: `HTTP Request`
   - URL: the function's URL from step 4
   - If you set `WEBHOOK_SECRET`, add header `Authorization: Bearer <that value>`

How it works: every signed-in device subscribes to the FCM topic `public-events`, plus one `group-<id>` topic per group it belongs to (kept in sync automatically as the user joins/leaves groups). The Edge Function (`supabase/functions/send-event-notification`) runs on every new event insert, works out which topic it belongs to from `event_type`/`group_id`, and sends one push to that topic — personal events never notify anyone. See the comment block at the end of [supabase/barangay_events.sql](supabase/barangay_events.sql) for the same summary alongside the schema.

Not yet built: tapping a notification opens the app but doesn't jump straight to that event, and iOS isn't wired up (no Apple Developer account/signing in this repo yet).
