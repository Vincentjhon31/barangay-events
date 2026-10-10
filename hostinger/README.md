# Hostinger file API — upload guide

This folder is a small PHP API that stores **event attachments** and **profile pictures** on the Hostinger site, while Supabase stays the database, login, and permission system. No XAMPP, no MySQL — Hostinger already runs PHP.

How it stays secure: every request carries the user's Supabase login token, and the API asks Supabase whether that person is allowed (as that person, so the database's existing rules apply). No Supabase secret key is ever stored on Hostinger.

```
hostinger/
  public_html/api/     -> upload into public_html/api/          (the API)
  public_html/media/   -> upload into public_html/media/        (profile pictures live here)
  private/             -> upload NEXT TO public_html, not inside it
  tests/               -> do NOT upload (local tests for developers)
```

## One-time setup (hPanel File Manager)

1. **Open the site's folder.** hPanel → Files → File Manager → open `domains/calendar.bongabong.gov.ph/` — the folder that *contains* `public_html`. Turn on **Show hidden files** (Settings in File Manager) so `.htaccess` files are visible.

2. **Create the private folder.** In `domains/calendar.bongabong.gov.ph/`, create a folder named **`private`** (next to `public_html`, not inside it). Inside it, create a folder named **`uploads`**.

3. **Add the settings file.** Upload `private/api-config.example.php` and `private/.htaccess` into that `private` folder, then rename `api-config.example.php` to **`api-config.php`**. Open it and check the two web addresses match your site (they're filled in for `calendar.bongabong.gov.ph`). Nothing in it is secret.

4. **Upload the API.** In `public_html`, create a folder **`api`** and upload every file from `hostinger/public_html/api/` into it — including **`.htaccess`**.
   Tip: zip the `api` folder on your computer, upload the zip into `public_html`, and use File Manager's **Extract**.

5. **Upload the media folder.** In `public_html`, create a folder **`media`** and upload `hostinger/public_html/media/.htaccess` into it. (Pictures are added here automatically later.)

6. **PHP settings.** hPanel → Advanced → **PHP Configuration**:
   - PHP version **8.1 or newer**;
   - extensions **gd**, **fileinfo**, **curl** switched on (they usually are);
   - **upload_max_filesize** and **post_max_size**: at least **16M**.

7. **Check it.** Open **https://calendar.bongabong.gov.ph/api/** in a browser. You should see something like:
   ```json
   {"ok":true,"gd":true,"curl":true,"fileinfo":true,"uploads_writable":true,"media_writable":true,...}
   ```
   Every value should be `true`. If `uploads_writable` or `media_writable` is `false`, set those folders' permissions to **755** (right-click → Permissions).

Final layout on the server:
```
domains/calendar.bongabong.gov.ph/
  public_html/
    (the Flutter web app files)
    api/        _lib.php, attachments.php, avatars.php, admin.php, index.php, .htaccess
    media/      .htaccess   (+ avatars/... created automatically)
  private/
    api-config.php, .htaccess
    uploads/    (event attachments, created automatically per event)
    link-secret.txt  (created automatically on first use — leave it alone)
```

## ⚠️ When you upload a new Flutter web build

The API sits next to the web app, so:

- [ ] Upload/replace the web build's files in `public_html` — **do not delete** the `api/` or `media/` folders.
- [ ] If you clear `public_html` first, back up `api/` and `media/` and put them back. **Deleting `media/` deletes everyone's uploaded profile pictures.**
- [ ] Never touch `private/` — event attachments live there.
- [ ] If the web build comes with its own `.htaccess` that sends every address to `index.html`, make sure it keeps the usual "skip real files" lines (`RewriteCond %{REQUEST_FILENAME} !-f` and `!-d`), or `/api/...` stops working.
- [ ] Afterwards, open **https://calendar.bongabong.gov.ph/api/** again to confirm it still says `"ok": true`.

## Troubleshooting

| What you see | Likely cause |
|---|---|
| `api-config.php is missing` | Step 3: the file must be at `private/api-config.php`, next to `public_html`. |
| "Your session has expired" although you're signed in | The server dropped the login header. Make sure `api/.htaccess` was uploaded (it's a hidden file). |
| The portal shows "Couldn't reach the file server" | The `api` folder isn't uploaded, or the portal runs on an address not in `ALLOWED_ORIGINS` in `api-config.php` — add it there. |
| "That file is too large" for small files | Raise upload_max_filesize / post_max_size (step 6). |
| Pictures upload but don't show | `media/` permissions (755), or the `MEDIA_PUBLIC_URL` address in `api-config.php`. |

## Testing locally (developers)

```
python hostinger/tests/run_tests.py
```
Runs the API under PHP's built-in server against a fake Supabase and checks permissions, file types, signed links, profile pictures, and the backup endpoints. Needs PHP 8 with gd, curl, and fileinfo. Doesn't touch Hostinger or Supabase.
