<?php
// Event attachments stored on Hostinger (the app's "Add attachment").
//
//   POST   attachments.php                 multipart: event_id, file
//          Only the event's poster may attach (checked in Supabase), up to
//          5 files per event, 10 MB each: pictures, PDF, Office documents.
//          Saves the file privately and records it in Supabase's
//          event_attachments table (as the user, so its RLS applies).
//   GET    attachments.php?id=<uuid>       the file, for anyone who can see
//          the event (Supabase decides — same rule as before).
//   GET    attachments.php?action=link&id=<uuid>
//          a signed link valid for 1 hour, for opening a document in
//          another app or the browser (which can't send the login token).
//   DELETE attachments.php?id=<uuid>       the poster removes a file.
//
// Files live in private/uploads, outside public_html, so they can never be
// opened directly — only through this script.

declare(strict_types=1);
require __DIR__ . '/_lib.php';
cors();

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
if ($method === 'POST') {
    upload_attachment();
} elseif ($method === 'GET' && ($_GET['action'] ?? '') === 'link') {
    attachment_link();
} elseif ($method === 'GET') {
    download_attachment();
} elseif ($method === 'DELETE') {
    delete_attachment();
}
fail('Method not allowed.', 405);

function upload_attachment(): void
{
    $user = require_user();
    $eventId = (string) ($_POST['event_id'] ?? '');
    if (!preg_match('/^[A-Za-z0-9_-]{1,64}$/', $eventId)) {
        fail('Missing or invalid event.');
    }

    $event = supabase_request('GET', '/rest/v1/barangay_events?select=id,created_by_id&id=eq.' . rawurlencode($eventId), $user['token']);
    if ($event['status'] !== 200 || empty($event['data'])) {
        fail('Event not found.', 404);
    }
    if (($event['data'][0]['created_by_id'] ?? null) !== $user['id']) {
        fail('Only the person who posted this event can attach files.', 403);
    }

    $existing = supabase_request('GET', '/rest/v1/event_attachments?select=id&event_id=eq.' . rawurlencode($eventId), $user['token']);
    if (is_array($existing['data']) && count($existing['data']) >= ATTACHMENTS_PER_EVENT) {
        fail('An event can have up to ' . ATTACHMENTS_PER_EVENT . ' files.', 409);
    }

    $file = uploaded_file('file', ATTACHMENT_MAX_BYTES);
    $mime = detect_mime($file['tmp_name']);
    $nameExt = strtolower(pathinfo((string) $file['name'], PATHINFO_EXTENSION));
    if (($mime === 'application/zip' || $mime === 'application/octet-stream') && isset(OFFICE_ZIP_EXTENSIONS[$nameExt])) {
        $mime = OFFICE_ZIP_EXTENSIONS[$nameExt];
    }
    if (!isset(ATTACHMENT_TYPES[$mime])) {
        fail("That type of file isn't allowed. Attach a picture, a PDF, or an Office document.", 415);
    }
    $ext = ATTACHMENT_TYPES[$mime];

    $relative = $eventId . '/' . random_name() . '.' . $ext;
    ensure_dir(UPLOADS_DIR . '/' . $eventId);
    $absolute = UPLOADS_DIR . '/' . $relative;
    if (!move_uploaded_file($file['tmp_name'], $absolute)) {
        fail('The server could not save the file.', 500);
    }

    $row = [
        'event_id' => $eventId,
        'storage_path' => $relative,
        'file_name' => clean_file_name((string) $file['name'], $ext),
        'mime_type' => $mime,
        'size_bytes' => filesize($absolute),
        'uploaded_by' => $user['id'],
        'storage_provider' => 'hostinger',
    ];
    $insert = supabase_request('POST', '/rest/v1/event_attachments', $user['token'], $row, ['Prefer: return=representation']);
    if ($insert['status'] !== 201 || empty($insert['data'][0])) {
        @unlink($absolute);
        fail('The file was not saved: ' . supabase_error($insert), 502);
    }
    json_out($insert['data'][0], 201);
}

/** The attachment's row, if the signed-in caller may see its event. */
function visible_attachment(string $id, array $user): array
{
    $res = supabase_request('GET', '/rest/v1/event_attachments?select=*&id=eq.' . rawurlencode($id), $user['token']);
    if ($res['status'] !== 200 || empty($res['data'][0])) {
        fail('File not found.', 404);
    }
    $row = $res['data'][0];
    if (($row['storage_provider'] ?? 'supabase') !== 'hostinger') {
        fail('That file is stored in Supabase, not here.', 404);
    }
    return $row;
}

function download_attachment(): void
{
    $id = (string) ($_GET['id'] ?? '');
    if (!is_uuid($id)) {
        fail('Missing or invalid file.');
    }

    // Signed link (from action=link): no login needed until it expires.
    if (isset($_GET['sig'])) {
        $path = safe_relative_path((string) ($_GET['path'] ?? ''));
        $expires = (int) ($_GET['exp'] ?? 0);
        $name = (string) ($_GET['name'] ?? 'file');
        $mime = (string) ($_GET['mime'] ?? 'application/octet-stream');
        $expected = sign($id . '|' . $path . '|' . $expires . '|' . $name . '|' . $mime);
        if ($path === null || $expires < time() || !hash_equals($expected, (string) $_GET['sig'])) {
            fail('This link has expired. Open the file from the app again.', 403);
        }
        send_file(UPLOADS_DIR . '/' . $path, $name, $mime);
    }

    $row = visible_attachment($id, require_user());
    $path = safe_relative_path((string) $row['storage_path']);
    if ($path === null) {
        fail('That file is no longer on the server.', 404);
    }
    send_file(UPLOADS_DIR . '/' . $path, (string) $row['file_name'], (string) ($row['mime_type'] ?? 'application/octet-stream'));
}

function attachment_link(): void
{
    $id = (string) ($_GET['id'] ?? '');
    if (!is_uuid($id)) {
        fail('Missing or invalid file.');
    }
    $row = visible_attachment($id, require_user());
    $path = safe_relative_path((string) $row['storage_path']);
    if ($path === null) {
        fail('That file is no longer on the server.', 404);
    }
    $expires = time() + 3600;
    $name = (string) $row['file_name'];
    $mime = (string) ($row['mime_type'] ?? 'application/octet-stream');
    $query = http_build_query([
        'id' => $id,
        'path' => $path,
        'exp' => $expires,
        'name' => $name,
        'mime' => $mime,
        'sig' => sign($id . '|' . $path . '|' . $expires . '|' . $name . '|' . $mime),
    ]);
    json_out(['url' => rtrim(API_PUBLIC_URL, '/') . '/attachments.php?' . $query, 'expires_at' => $expires]);
}

function delete_attachment(): void
{
    $id = (string) ($_GET['id'] ?? '');
    if (!is_uuid($id)) {
        fail('Missing or invalid file.');
    }
    $user = require_user();
    $row = visible_attachment($id, $user);
    // Supabase's delete rule (poster only) decides; nothing comes back if
    // this user may not delete it.
    $res = supabase_request('DELETE', '/rest/v1/event_attachments?id=eq.' . rawurlencode($id), $user['token'], null, ['Prefer: return=representation']);
    if ($res['status'] !== 200 || empty($res['data'])) {
        fail('Only the person who posted this event can remove its files.', 403);
    }
    $path = safe_relative_path((string) $row['storage_path']);
    if ($path !== null) {
        @unlink(UPLOADS_DIR . '/' . $path);
    }
    json_out(['deleted' => true]);
}
