<?php
// Superadmin-only file access for the LGU-admin portal's Backups and System
// pages. Two storage areas:
//   uploads — private event attachments (private/uploads)
//   media   — profile pictures (public_html/media)
//
//   GET  admin.php?action=usage                     size and file count per area
//   GET  admin.php?action=list&area=uploads|media   every stored file's path
//   GET  admin.php?action=get&area=..&path=..       one file (for a backup ZIP)
//   POST admin.php?action=put&area=..&path=..       multipart: file (restore)

declare(strict_types=1);
require __DIR__ . '/_lib.php';
cors();

require_superadmin();

$action = (string) ($_GET['action'] ?? '');
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method === 'GET' && $action === 'usage') {
    json_out([
        'uploads' => folder_usage(UPLOADS_DIR),
        'media' => folder_usage(MEDIA_DIR . '/avatars'),
    ]);
}

$area = (string) ($_GET['area'] ?? '');
$root = area_root($area);

if ($method === 'GET' && $action === 'list') {
    $files = [];
    if (is_dir($root)) {
        $iterator = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($root, FilesystemIterator::SKIP_DOTS));
        foreach ($iterator as $item) {
            if (!$item->isFile() || $item->getFilename()[0] === '.') {
                continue;
            }
            $relative = str_replace('\\', '/', substr($item->getPathname(), strlen($root) + 1));
            if ($area === 'media') {
                $relative = 'avatars/' . $relative;
            }
            if (safe_relative_path($relative) !== null) {
                $files[] = ['path' => $relative, 'bytes' => $item->getSize()];
            }
        }
    }
    json_out(['area' => $area, 'files' => $files]);
}

if ($action === 'get' || $action === 'put') {
    $path = area_path($area, (string) ($_GET['path'] ?? ''));
    $absolute = ($area === 'media' ? MEDIA_DIR : UPLOADS_DIR) . '/' . $path;
    if ($method === 'GET' && $action === 'get') {
        send_file($absolute, basename($path), detect_mime_or_default($absolute));
    }
    if ($method === 'POST' && $action === 'put') {
        $file = uploaded_file('file', 50 * 1024 * 1024);
        ensure_dir(dirname($absolute));
        if (!move_uploaded_file($file['tmp_name'], $absolute)) {
            fail('The server could not save the file.', 500);
        }
        json_out(['restored' => $path], 201);
    }
}

fail('Unknown action.', 400);

/** The folder [$area] lists from (media lists only its avatars folder). */
function area_root(string $area): string
{
    if ($area === 'uploads') {
        return UPLOADS_DIR;
    }
    if ($area === 'media') {
        return MEDIA_DIR . '/avatars';
    }
    fail('Unknown area — use uploads or media.');
    return '';
}

/** A validated path inside [$area] (media paths always start with avatars/). */
function area_path(string $area, string $path): string
{
    $safe = safe_relative_path($path);
    if ($safe === null || ($area === 'media' && strpos($safe, 'avatars/') !== 0)) {
        fail('Invalid file path.');
    }
    return $safe;
}

function detect_mime_or_default(string $absolute): string
{
    return is_file($absolute) ? detect_mime($absolute) : 'application/octet-stream';
}
