<?php
// Health check: open https://<your-site>/api/ in a browser after uploading.
// "ok": true with everything else true means the API is ready.

declare(strict_types=1);
require __DIR__ . '/_lib.php';
cors();

$uploadsWritable = is_dir(UPLOADS_DIR) ? is_writable(UPLOADS_DIR) : is_writable(dirname(UPLOADS_DIR));
$mediaWritable = is_dir(MEDIA_DIR) ? is_writable(MEDIA_DIR) : false;

json_out([
    'ok' => true,
    'service' => 'eBongabong Calendar file API',
    'php' => PHP_VERSION,
    'gd' => extension_loaded('gd'),
    'curl' => extension_loaded('curl'),
    'fileinfo' => extension_loaded('fileinfo'),
    'uploads_writable' => $uploadsWritable,
    'media_writable' => $mediaWritable,
    'max_upload' => ini_get('upload_max_filesize'),
    'max_post' => ini_get('post_max_size'),
]);
