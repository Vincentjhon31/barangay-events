# Hostinger file API — upload guide

This folder is a small PHP API that stores **event attachments** and **profile pictures** on the Hostinger site, while Supabase stays the database, login, and permission system. No XAMPP, no MySQL — Hostinger already runs PHP.

How it stays secure: every request carries the user's Supabase login token, and the API asks Supabase whether that person is allowed (as that person, so the database's existing rules apply). No Supabase secret key is ever stored on Hostinger.

Everything goes **inside the subdomain's folder** (`calendar`, the folder that holds the web app's `index.html`):

```
hostinger/public_html/api/     -> calendar/api/
hostinger/public_html/media/   -> calendar/media/
hostinger/private/             -> calendar/private/
hostinger/tests/               -> do NOT upload (local tests for developers)
```

## One-time setup (hPanel File Manager)

1. **Open the subdomain's folder.** hPanel → Files → File Manager → open the **`calendar`** folder (where the web app's `index.html` is). Turn on **Show hidden files** (File Manager settings) — the `.htaccess` files are hidden files and they matter.

2. **Create the private folder.** Inside `calendar`, create a folder **`private`**, and inside it a folder **`uploads`**.

3. **Upload the private files.** Upload `hostinger/private/.htaccess`, `hostinger/private/index.php`, and `hostinger/private/api-config.example.php` into `calendar/private/`. Then rename `api-config.example.php` to **`api-config.php`**. It's already filled in for `calendar.bongabong.gov.ph`; nothing in it is secret.
   **`private/.htaccess` is what keeps attachments from being opened directly in a browser — don't skip it.**

4. **Upload the API.** Inside `calendar`, create a folder **`api`** and upload every file from `hostinger/public_html/api/` — including **`.htaccess`**.
   Tip: zip the folder on your computer, upload the zip, and use File Manager's **Extract**.

5. **Upload the media folder.** Inside `calendar`, create a folder **`media`** and upload `hostinger/public_html/media/.htaccess` into it. (Pictures are added here automatically later.)

6. **PHP settings.** hPanel → Advanced → **PHP Configuration**:
   - PHP version **8.1 or newer**;
   - extensions **gd**, **fileinfo**, **curl** switched on (they usually are);
   - **upload_max_filesize** and **post_max_size**: at least **16M**.

7. **Check it.** Open **https://calendar.bongabong.gov.ph/api/** in a browser. You should see something like:
   ```json
   {"ok":true,"gd":true,"curl":true,"fileinfo":true,"uploads_writable":true,
    "media_writable":true,"private_protected":true,...}
   ```
   - **`private_protected` must be `true`.** The API tries to open a test file in `private` the way a stranger would; `true` means it was blocked. If it says `false`, `private/.htaccess` is missing — upload it (step 3) before anyone attaches files.
   - If it says `null`, open **https://calendar.bongabong.gov.ph/private/protected-check.txt** yourself: it must show **403 Forbidden**, not the text.
   - If `uploads_writable` or `media_writable` is `false`, set those folders' permissions to **755** (right-click → Permissions).

Final layout on the server:
```
calendar/
  index.html, main.dart.js, ... (the Flutter web app)
  api/       _lib.php, attachments.php, avatars.php, admin.php, index.php, .htaccess
  media/     .htaccess   (+ avatars/... created automatically)
  private/   .htaccess, index.php, api-config.php
             uploads/          (event attachments, created automatically per event)
             link-secret.txt   (created automatically — leave it alone)
             protected-check.txt (created by the health check — leave it alone)
```

## ⚠️ When you upload a new Flutter web build

The API and everyone's files now live in the same folder as the web app, so:

- [ ] Upload/replace the web build's files — **never delete `api/`, `media/`, or `private/`**.
- [ ] Don't use "delete all and re-upload" on the `calendar` folder. **Deleting `private/` deletes every event attachment; deleting `media/` deletes everyone's uploaded profile pictures.** If you must clear the folder, download those three folders first and put them back.
- [ ] If the web build comes with its own `.htaccess` that sends every address to `index.html`, make sure it keeps the usual "skip real files" lines (`RewriteCond %{REQUEST_FILENAME} !-f` and `!-d`), or `/api/...` stops working.
- [ ] Afterwards, open **https://calendar.bongabong.gov.ph/api/** again: `"ok": true` and `"private_protected": true`.

## Troubleshooting

| What you see | Likely cause |
|---|---|
| `api-config.php is missing` | Step 3: the file must be at `calendar/private/api-config.php`. |
| `"private_protected": false` | `private/.htaccess` wasn't uploaded (hidden file). Upload it, then check again. |
| "Your session has expired" although you're signed in | The server dropped the login header. Make sure `api/.htaccess` was uploaded (it's a hidden file). |
| The portal shows "Couldn't reach the file server" | The `api` folder isn't uploaded, or the portal runs on an address not in `ALLOWED_ORIGINS` in `api-config.php` — add it there. |
| "That file is too large" for small files | Raise upload_max_filesize / post_max_size (step 6). |
| Pictures upload but don't show | `media/` permissions (755), or the `MEDIA_PUBLIC_URL` address in `api-config.php`. |

## Testing locally (developers)

```
python hostinger/tests/run_tests.py
```
Runs the API under PHP's built-in server against a fake Supabase, in the same `calendar/` layout, and checks permissions, file types, signed links, profile pictures, the backup endpoints, and that the health check catches an unprotected `private` folder (PHP's built-in server ignores `.htaccess`, so there it correctly reports `false`). Needs PHP 8 with gd, curl, and fileinfo. Doesn't touch Hostinger or Supabase.
