<?php
// Profile pictures stored on Hostinger.
//
//   POST   avatars.php                        multipart: file
//          The signed-in user's own photo: re-encoded as a 512x512 JPEG,
//          saved under media/avatars/users/, set as their profile picture
//          in Supabase, and their previous uploaded photo deleted.
//   DELETE avatars.php                        removes the user's own photo
//          files (called after they switch back to a preset picture).
//
//   Superadmin only:
//   POST   avatars.php?action=preset          multipart: category, file
//          adds a picture to the Anime / Animal / Person choices
//          (Supabase table avatar_presets).
//   DELETE avatars.php?action=preset&id=<uuid>
//   POST   avatars.php?action=remove-user-photo   form: user_id
//          moderation: deletes someone's uploaded photo and resets them to
//          no picture (Supabase RPC admin_reset_avatar).
//
// Pictures are public links with unguessable names (they appear in group
// member lists, chats, and on events), so they're served straight from
// media/ by the web server.

declare(strict_types=1);
require __DIR__ . '/_lib.php';
cors();

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$action = (string) ($_GET['action'] ?? '');
if ($method === 'POST' && $action === '') {
    upload_own_photo();
} elseif ($method === 'DELETE' && $action === '') {
    delete_own_photo();
} elseif ($method === 'POST' && $action === 'preset') {
    add_preset();
} elseif ($method === 'DELETE' && $action === 'preset') {
    delete_preset();
} elseif ($method === 'POST' && $action === 'remove-user-photo') {
    remove_user_photo();
}
fail('Method not allowed.', 405);

function user_photo_dir(): string
{
    return MEDIA_DIR . '/avatars/users';
}

/** Deletes [$userId]'s uploaded photo files, except [$keep]. */
function delete_user_photo_files(string $userId, ?string $keep = null): void
{
    foreach (glob(user_photo_dir() . '/' . $userId . '-*.jpg') ?: [] as $file) {
        if ($keep === null || basename($file) !== $keep) {
            @unlink($file);
        }
    }
}

function upload_own_photo(): void
{
    $user = require_user();
    $file = uploaded_file('file', AVATAR_MAX_UPLOAD_BYTES);
    $jpeg = square_jpeg($file['tmp_name'], AVATAR_SIZE);

    ensure_dir(user_photo_dir());
    $name = $user['id'] . '-' . random_name() . '.jpg';
    if (file_put_contents(user_photo_dir() . '/' . $name, $jpeg, LOCK_EX) === false) {
        fail('The server could not save the picture.', 500);
    }
    $url = rtrim(MEDIA_PUBLIC_URL, '/') . '/avatars/users/' . $name;

    $update = supabase_request('PATCH', '/rest/v1/profiles?id=eq.' . rawurlencode($user['id']), $user['token'], ['avatar_url' => $url], ['Prefer: return=minimal']);
    if ($update['status'] < 200 || $update['status'] >= 300) {
        @unlink(user_photo_dir() . '/' . $name);
        fail('Your picture was not saved: ' . supabase_error($update), 502);
    }
    delete_user_photo_files($user['id'], $name);
    json_out(['url' => $url], 201);
}

function delete_own_photo(): void
{
    $user = require_user();
    delete_user_photo_files($user['id']);
    json_out(['deleted' => true]);
}

function add_preset(): void
{
    $user = require_superadmin();
    $category = (string) ($_POST['category'] ?? '');
    if (!in_array($category, AVATAR_CATEGORIES, true)) {
        fail('Pick a category: ' . implode(', ', AVATAR_CATEGORIES) . '.');
    }
    $file = uploaded_file('file', AVATAR_MAX_UPLOAD_BYTES);
    $jpeg = square_jpeg($file['tmp_name'], AVATAR_SIZE);

    $relative = 'avatars/presets/' . $category . '/' . random_name() . '.jpg';
    ensure_dir(MEDIA_DIR . '/avatars/presets/' . $category);
    if (file_put_contents(MEDIA_DIR . '/' . $relative, $jpeg, LOCK_EX) === false) {
        fail('The server could not save the picture.', 500);
    }
    $row = [
        'category' => $category,
        'url' => rtrim(MEDIA_PUBLIC_URL, '/') . '/' . $relative,
        'storage_path' => $relative,
        'created_by' => $user['id'],
    ];
    $insert = supabase_request('POST', '/rest/v1/avatar_presets', $user['token'], $row, ['Prefer: return=representation']);
    if ($insert['status'] !== 201 || empty($insert['data'][0])) {
        @unlink(MEDIA_DIR . '/' . $relative);
        fail('The picture was not saved: ' . supabase_error($insert), 502);
    }
    json_out($insert['data'][0], 201);
}

function delete_preset(): void
{
    $user = require_superadmin();
    $id = (string) ($_GET['id'] ?? '');
    if (!is_uuid($id)) {
        fail('Missing or invalid picture.');
    }
    $res = supabase_request('DELETE', '/rest/v1/avatar_presets?id=eq.' . rawurlencode($id), $user['token'], null, ['Prefer: return=representation']);
    if ($res['status'] !== 200 || empty($res['data'][0])) {
        fail('Picture not found.', 404);
    }
    $path = safe_relative_path((string) ($res['data'][0]['storage_path'] ?? ''));
    if ($path !== null && strpos($path, 'avatars/presets/') === 0) {
        @unlink(MEDIA_DIR . '/' . $path);
    }
    json_out(['deleted' => true]);
}

function remove_user_photo(): void
{
    $user = require_superadmin();
    $target = (string) ($_POST['user_id'] ?? '');
    if (!is_uuid($target)) {
        fail('Missing or invalid account.');
    }
    $reset = supabase_request('POST', '/rest/v1/rpc/admin_reset_avatar', $user['token'], ['p_user_id' => $target]);
    if ($reset['status'] < 200 || $reset['status'] >= 300) {
        fail('The picture was not removed: ' . supabase_error($reset), 502);
    }
    delete_user_photo_files($target);
    json_out(['removed' => true]);
}
