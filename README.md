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

## Web Build (calendar.bongabong.gov.ph, hosted on Hostinger)

```powershell
flutter build web --no-tree-shake-icons
```

`--no-tree-shake-icons` is required — Flutter's icon tree-shaker misdetects
which `font_awesome_flutter` glyphs are actually used (it wrongly stripped
`shieldHalved`, `userShield`, and `mapLocationDot` down to 33 surviving
glyphs out of 2000+, showing as broken-glyph boxes in the app). Upload the
contents of `build/web` to the Hostinger site root.

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
3. Set it as a secret for the Edge Function, **base64-encoded** (PowerShell):
   ```powershell
   $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((Get-Content -Raw "path\to\service-account.json")))
   supabase secrets set "FCM_SERVICE_ACCOUNT_JSON_B64=$b64"
   ```
   Base64 is deliberate, not optional — the raw JSON is nothing but double-quoted text, and PowerShell does not reliably pass strings full of embedded double-quotes through to native executables as a single argument (this bit us once: the secret silently got corrupted and the function crashed on every invocation with a `JSON.parse` error). Base64 has no characters a shell can mangle.
4. Deploy the function: `supabase functions deploy send-event-notification --use-api` (from the repo root; needs the Supabase CLI logged into this project — `--use-api` bundles without requiring Docker Desktop to be running).
5. **Supabase Dashboard** → your project → **Integrations → Webhooks** (`/integrations/webhooks/webhooks` — the old `/database/hooks` URL has moved) → *Create a new webhook*:
   - Table: `barangay_events`, Event: `INSERT`
   - Type: **Supabase Edge Functions** (not "HTTP Request" — this type auto-attaches valid auth, avoiding a separate `WEBHOOK_SECRET`/header setup)
   - Edge Function: select `send-event-notification` from the dropdown

How it works: every signed-in device subscribes to the FCM topic `public-events`, plus one `group-<id>` topic per group it belongs to (kept in sync automatically as the user joins/leaves groups). The Edge Function (`supabase/functions/send-event-notification`) runs on every new event insert, works out which topic it belongs to from `event_type`/`group_id`, and sends one push to that topic — personal events never notify anyone. See the comment block at the end of [supabase/barangay_events.sql](supabase/barangay_events.sql) for the same summary alongside the schema.

Not yet built: tapping a notification opens the app but doesn't jump straight to that event, and iOS isn't wired up (no Apple Developer account/signing in this repo yet).

### App update notifications

A new tagged release also pushes a "New version available" notification (topic `app-updates`, every device subscribes automatically) and refreshes the in-app update banner immediately if the app is already open — see the **About** page (Profile → About) for version info, a manual "Check for updates" button, and the latest release's notes. One-time setup, on top of the Firebase steps above (this reuses the same `FCM_SERVICE_ACCOUNT_JSON_B64` secret — no second Firebase credential needed):

1. Pick a random secret string and set it in two places (same value in both):
   ```powershell
   supabase secrets set "RELEASE_NOTIFY_SECRET=<paste-a-random-string-here>"
   ```
   and as a GitHub repo secret named `RELEASE_NOTIFY_SECRET` (**Settings → Secrets and variables → Actions**) — same place as `KEYSTORE_FILE`/`KEYSTORE_PASSWORD`/etc.
2. Deploy the function **without** JWT verification, since it's called directly by GitHub Actions rather than through a Supabase-authenticated Database Webhook like `send-event-notification` is:
   ```powershell
   supabase functions deploy send-app-update-notification --use-api --no-verify-jwt
   ```

How it works: `.github/workflows/release.yml` calls this function right after publishing a GitHub Release, passing the version tag; the function checks `Authorization: Bearer <RELEASE_NOTIFY_SECRET>` itself (since there's no Supabase webhook auto-auth here) and sends one push to the `app-updates` topic. If `RELEASE_NOTIFY_SECRET` isn't set yet, that workflow step is skipped without failing the release.

### Event chat notifications

A new message in an event's chat pushes a notification (Android "Event chat" channel, so people can mute chats separately from event announcements) and, if the app is open, shows an in-app toast — skipped for the chat that's already on screen. Recipients: every member of a **group** event's group; for a **public** event, its creator plus everyone who has written in that chat; never the sender, never personal events. Each push goes to the recipient's own `user-<uid>` topic. Tapping it opens that chat.

No new secrets — it reuses `FCM_SERVICE_ACCOUNT_JSON_B64` and the reminder job's `REMINDER_CRON_SECRET` / vault secret `reminder_cron_secret`. One-time setup:

1. Run the "Event chat" blocks at the end of [supabase/barangay_events.sql](supabase/barangay_events.sql) (they add the `notify_event_comment` trigger, which calls the function through `pg_net` — no dashboard webhook needed).
2. Deploy the function **without** JWT verification (the bearer token is the shared secret, not a JWT):
   ```powershell
   supabase functions deploy send-chat-notification --use-api --no-verify-jwt
   ```

## LGU Admin Portal

The superadmin's "Add account" card (docs/lgu-admin/, signed in as superadmin) creates an LGU member or another superadmin account directly — no self-registration/approval step. One-time setup:

```powershell
supabase functions deploy admin-create-account --use-api
```

No secrets to configure — it only needs `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY`, both auto-injected into every Edge Function's environment already. Unlike `send-app-update-notification`, deploy this one **with** the default JWT verification on (no `--no-verify-jwt`) — it's called by a real signed-in browser session, and the function's entire security boundary depends on Supabase rejecting anything without a valid user JWT before the function code runs.

### Roles: admin vs superadmin

- **Admin** — runs events and groups from the mobile app (Public events, managing groups, event locations, chat moderation). The superadmin can switch each of the first three off per admin (portal → Users → Admins). Admins can't open the portal.
- **Superadmin** — the only role the portal lets in: accounts, admins and their permissions, custom calendars, backups and restore, database monitoring. Has every admin power in the app too.

Every portal RPC and admin-* Edge Function checks for `superadmin`; in-app powers go through the `has_admin_permission()` / `is_staff_admin()` SQL helpers.

### Calendars, backups, and monitoring

- **Calendars** (portal → Calendars): e.g. a "Sports" calendar. Each becomes its own filter tab in the app's Calendar and Feed (after All / Public / Group / Personal) and everyone sees its events. Only the handlers the superadmin assigns (any account) can post to it, from Add Event; new events notify everyone. Removing one asks Archive (tab hidden, no new posts, restorable) or Delete permanently (its events become regular Public events).
- **Backups** (portal → Backups): one ZIP with every table as JSON + CSV, every event attachment, the schema, and a README — portable to another back end. Passwords aren't exported; restored accounts use "Forgot password". Restore is **Merge** (safe upsert) or **Replace** (wipes content first; type RESTORE). Restores run with triggers off, so no push notifications fire. A dashboard banner reminds the superadmin when a backup is due (interval set on the Backups page).
- **System** (portal → System): database size, file storage, per-table sizes and record counts, against the plan limits you enter.

One-time setup: run the "Admin role + one real superadmin", "Custom calendars", and "Database monitoring + backup & restore" blocks at the end of [supabase/barangay_events.sql](supabase/barangay_events.sql), then:

```powershell
supabase functions deploy admin-backup --use-api
supabase functions deploy admin-create-account --use-api
supabase functions deploy send-event-notification --use-api
```

**Release order matters:** apply the SQL before publishing an app build that includes calendars (the app retries event saves without `calendar_id` if the column is missing, but calendar tabs only appear once the table exists).
