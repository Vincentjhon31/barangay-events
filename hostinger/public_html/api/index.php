<?php
// Health check: open https://<your-site>/api/ in a browser after uploading.
// Everything true means the API is ready. "private_protected" must be true:
// it confirms the private folder (settings + event attachments) can't be
// opened from the web.

declare(strict_types=1);
require __DIR__ . '/_lib.php';
cors();

$uploadsWritable = is_dir(UPLOADS_DIR) ? is_writable(UPLOADS_DIR) : is_writable(dirname(UPLOADS_DIR));
$mediaWritable = is_dir(MEDIA_DIR) ? is_writable(MEDIA_DIR) : false;

/**
 * Tries to download a marker file from private/ over the web, the way a
 * stranger would. true = blocked (good), false = readable (NOT protected),
 * null = couldn't tell (e.g. the server can't reach its own address).
 */
function private_folder_protected(): ?bool
{
    if (!defined('PRIVATE_PUBLIC_URL')) {
        return null;
    }
    $marker = 'If you can read this from a browser, the private folder is NOT protected.';
    $file = PRIVATE_DIR . '/protected-check.txt';
    if (!is_file($file)) {
        @file_put_contents($file, $marker);
    }
    $ch = curl_init(rtrim(PRIVATE_PUBLIC_URL, '/') . '/protected-check.txt');
    curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_CONNECTTIMEOUT => 5, CURLOPT_TIMEOUT => 8]);
    $body = curl_exec($ch);
    $status = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    curl_close($ch);
    if ($body === false || $status === 0) {
        return null;
    }
    return !($status === 200 && strpos((string) $body, $marker) !== false);
}

$protected = private_folder_protected();
$result = [
    'ok' => true,
    'service' => 'eBongabong Calendar file API',
    'php' => PHP_VERSION,
    'gd' => extension_loaded('gd'),
    'curl' => extension_loaded('curl'),
    'fileinfo' => extension_loaded('fileinfo'),
    'uploads_writable' => $uploadsWritable,
    'media_writable' => $mediaWritable,
    'private_protected' => $protected,
    'max_upload' => ini_get('upload_max_filesize'),
    'max_post' => ini_get('post_max_size'),
];
if ($protected === false) {
    $result['ok'] = false;
    $result['warning'] = 'The private folder can be opened from the web. Upload private/.htaccess (a hidden file) before using attachments.';
} elseif ($protected === null) {
    $result['note'] = 'Could not check the private folder automatically. Open PRIVATE_PUBLIC_URL/protected-check.txt in a browser: it must show "403 Forbidden".';
}
json_out($result);
