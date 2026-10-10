<?php
// Shared helpers for the eBongabong Calendar file API (attachments and
// profile pictures stored on Hostinger). Not a page — every endpoint in
// this folder requires it.
//
// The database, logins and permissions all stay in Supabase. This API only
// stores the file bytes, and every request is checked against Supabase:
// the caller's own Supabase login token is verified with Supabase Auth,
// and permission checks are Supabase queries made AS that user, so the
// database's row-level security rules decide what they may see or change.
// No Supabase secret key is ever stored on this server.

declare(strict_types=1);

$configPath = __DIR__ . '/../../private/api-config.php';
if (!is_file($configPath)) {
    http_response_code(500);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['error' => 'Server not configured: private/api-config.php is missing.']);
    exit;
}
require $configPath;

const ATTACHMENT_MAX_BYTES = 10 * 1024 * 1024;
const ATTACHMENTS_PER_EVENT = 5;
const AVATAR_MAX_UPLOAD_BYTES = 8 * 1024 * 1024;
const AVATAR_SIZE = 512;
const AVATAR_CATEGORIES = ['anime', 'animal', 'person'];

// Accepted attachment types (detected from the file's contents, not its
// name) and the extension each is saved with.
const ATTACHMENT_TYPES = [
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    'application/pdf' => 'pdf',
    'application/msword' => 'doc',
    'application/vnd.ms-excel' => 'xls',
    'application/vnd.ms-powerpoint' => 'ppt',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => 'docx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => 'xlsx',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation' => 'pptx',
];

// Office files are ZIP archives inside, and some servers' file-type
// detection only says "zip" — accept them by their extension then.
const OFFICE_ZIP_EXTENSIONS = [
    'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
];

// Every file extension this API ever stores (used to validate paths).
const STORED_EXTENSIONS = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'];

/** CORS for the browser-based callers (web app, admin portal). */
function cors(): void
{
    $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
    if ($origin !== '' && in_array($origin, ALLOWED_ORIGINS, true)) {
        header('Access-Control-Allow-Origin: ' . $origin);
        header('Vary: Origin');
        header('Access-Control-Allow-Headers: Authorization, X-Auth-Token, Content-Type');
        header('Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS');
        header('Access-Control-Expose-Headers: Content-Disposition');
        header('Access-Control-Max-Age: 86400');
    }
    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}

function json_out($data, int $status = 200): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode($data, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

function fail(string $message, int $status = 400): void
{
    json_out(['error' => $message], $status);
}

/**
 * The caller's Supabase access token. Read from several places because some
 * hosting setups strip the Authorization header before PHP sees it; the
 * apps also send it as X-Auth-Token for that reason.
 */
function bearer_token(): ?string
{
    $candidates = [
        $_SERVER['HTTP_AUTHORIZATION'] ?? null,
        $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? null,
    ];
    if (function_exists('getallheaders')) {
        foreach (getallheaders() as $name => $value) {
            if (strcasecmp((string) $name, 'Authorization') === 0) {
                $candidates[] = $value;
            }
        }
    }
    foreach ($candidates as $candidate) {
        if (is_string($candidate) && preg_match('/^Bearer\s+(\S+)$/i', trim($candidate), $m)) {
            return $m[1];
        }
    }
    $fallback = $_SERVER['HTTP_X_AUTH_TOKEN'] ?? '';
    return is_string($fallback) && preg_match('/^\S+$/', $fallback) ? $fallback : null;
}

/**
 * A request to Supabase (Auth or the REST API) made as [$token]'s user, so
 * the database's row-level security applies exactly as it does in the app.
 */
function supabase_request(string $method, string $path, ?string $token, $body = null, array $extraHeaders = []): array
{
    $ch = curl_init(rtrim(SUPABASE_URL, '/') . $path);
    $headers = ['apikey: ' . SUPABASE_KEY, 'Accept: application/json'];
    if ($token !== null) {
        $headers[] = 'Authorization: Bearer ' . $token;
    }
    if ($body !== null) {
        $headers[] = 'Content-Type: application/json';
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body, JSON_UNESCAPED_SLASHES));
    }
    foreach ($extraHeaders as $header) {
        $headers[] = $header;
    }
    curl_setopt_array($ch, [
        CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_TIMEOUT => 25,
    ]);
    $raw = curl_exec($ch);
    $status = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    $error = curl_error($ch);
    curl_close($ch);
    if ($raw === false) {
        return ['status' => 0, 'data' => null, 'error' => $error];
    }
    return ['status' => $status, 'data' => $raw === '' ? null : json_decode((string) $raw, true), 'error' => null];
}

function supabase_error(array $response): string
{
    if (is_array($response['data']) && isset($response['data']['message'])) {
        return (string) $response['data']['message'];
    }
    return $response['error'] ?? ('HTTP ' . $response['status']);
}

/** Verifies the caller with Supabase Auth; stops with 401 if not signed in. */
function require_user(): array
{
    $token = bearer_token();
    if ($token === null) {
        fail('Sign in first.', 401);
    }
    $res = supabase_request('GET', '/auth/v1/user', $token);
    if ($res['status'] !== 200 || !is_array($res['data']) || empty($res['data']['id'])) {
        fail('Your session has expired. Sign in again.', 401);
    }
    return ['id' => (string) $res['data']['id'], 'token' => $token];
}

function user_role(array $user): string
{
    $res = supabase_request('GET', '/rest/v1/profiles?select=role&id=eq.' . rawurlencode($user['id']), $user['token']);
    return ($res['status'] === 200 && isset($res['data'][0]['role'])) ? (string) $res['data'][0]['role'] : 'citizen';
}

function require_superadmin(): array
{
    $user = require_user();
    if (user_role($user) !== 'superadmin') {
        fail('Only the superadmin can do that.', 403);
    }
    return $user;
}

function is_uuid(string $value): bool
{
    return (bool) preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $value);
}

function random_name(): string
{
    return bin2hex(random_bytes(16));
}

function ensure_dir(string $dir): void
{
    if (!is_dir($dir) && !mkdir($dir, 0755, true) && !is_dir($dir)) {
        fail('The server could not create a storage folder.', 500);
    }
}

function detect_mime(string $path): string
{
    $info = new finfo(FILEINFO_MIME_TYPE);
    return (string) $info->file($path);
}

/** A validated, fully received upload from the multipart field [$field]. */
function uploaded_file(string $field, int $maxBytes): array
{
    if (!isset($_FILES[$field]) || !is_array($_FILES[$field])) {
        fail('No file was sent.');
    }
    $file = $_FILES[$field];
    $error = $file['error'] ?? UPLOAD_ERR_NO_FILE;
    if ($error === UPLOAD_ERR_INI_SIZE || $error === UPLOAD_ERR_FORM_SIZE) {
        fail('That file is too large.', 413);
    }
    if ($error !== UPLOAD_ERR_OK || !is_uploaded_file($file['tmp_name'])) {
        fail('The upload did not finish. Try again.');
    }
    if ((int) $file['size'] > $maxBytes) {
        fail('That file is too large (up to ' . (int) round($maxBytes / 1048576) . ' MB).', 413);
    }
    return $file;
}

/**
 * Re-encodes an uploaded picture as a square JPEG of [$size] pixels:
 * center-cropped, rotated upright, and stripped of anything but pixels
 * (no metadata, no hidden payloads).
 */
function square_jpeg(string $sourcePath, int $size): string
{
    $image = @imagecreatefromstring((string) file_get_contents($sourcePath));
    if ($image === false) {
        fail('That picture could not be read. Use a JPG, PNG, or WebP image.', 415);
    }
    if (function_exists('exif_read_data') && detect_mime($sourcePath) === 'image/jpeg') {
        $exif = @exif_read_data($sourcePath);
        $angle = [3 => 180, 6 => -90, 8 => 90][(int) ($exif['Orientation'] ?? 1)] ?? 0;
        if ($angle !== 0) {
            $rotated = imagerotate($image, $angle, 0);
            if ($rotated !== false) {
                imagedestroy($image);
                $image = $rotated;
            }
        }
    }
    $width = imagesx($image);
    $height = imagesy($image);
    $side = min($width, $height);
    $out = imagecreatetruecolor($size, $size);
    imagefill($out, 0, 0, imagecolorallocate($out, 255, 255, 255));
    imagecopyresampled($out, $image, 0, 0, intdiv($width - $side, 2), intdiv($height - $side, 2), $size, $size, $side, $side);
    ob_start();
    imagejpeg($out, null, 85);
    $jpeg = (string) ob_get_clean();
    imagedestroy($image);
    imagedestroy($out);
    return $jpeg;
}

/** A file name safe to show and to send in a download header. */
function clean_file_name(string $name, string $extension): string
{
    $base = pathinfo($name, PATHINFO_FILENAME);
    $base = preg_replace('/[^\p{L}\p{N} ._()-]+/u', '', $base) ?? '';
    $base = trim(mb_substr($base, 0, 80));
    return ($base === '' ? 'file' : $base) . '.' . $extension;
}

/**
 * A stored file's path relative to a storage area, accepted only if it's
 * plain (no "..", no odd characters) and has a stored-file extension.
 */
function safe_relative_path(string $path): ?string
{
    if ($path === '' || strlen($path) > 300 || strpos($path, '..') !== false) {
        return null;
    }
    if (!preg_match('#^[A-Za-z0-9_-]+(/[A-Za-z0-9_.-]+)+$#', $path)) {
        return null;
    }
    $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));
    return in_array($ext, STORED_EXTENSIONS, true) ? $path : null;
}

/** A per-server secret for signed download links, created on first use. */
function link_secret(): string
{
    $file = PRIVATE_DIR . '/link-secret.txt';
    if (is_file($file)) {
        $secret = trim((string) file_get_contents($file));
        if (strlen($secret) >= 32) {
            return $secret;
        }
    }
    $secret = bin2hex(random_bytes(32));
    file_put_contents($file, $secret, LOCK_EX);
    @chmod($file, 0600);
    return $secret;
}

function sign(string $payload): string
{
    return hash_hmac('sha256', $payload, link_secret());
}

/** Streams a stored file to the client. */
function send_file(string $absolutePath, string $downloadName, string $mime): void
{
    if (!is_file($absolutePath)) {
        fail('That file is no longer on the server.', 404);
    }
    $inline = strpos($mime, 'image/') === 0 || $mime === 'application/pdf';
    header('Content-Type: ' . $mime);
    header('Content-Length: ' . filesize($absolutePath));
    header('X-Content-Type-Options: nosniff');
    header('Cache-Control: private, max-age=3600');
    header('Content-Disposition: ' . ($inline ? 'inline' : 'attachment') . "; filename*=UTF-8''" . rawurlencode($downloadName));
    readfile($absolutePath);
    exit;
}

/** Total size and count of the files under [$dir]. */
function folder_usage(string $dir): array
{
    $bytes = 0;
    $files = 0;
    if (is_dir($dir)) {
        $iterator = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($dir, FilesystemIterator::SKIP_DOTS));
        foreach ($iterator as $item) {
            if ($item->isFile() && $item->getFilename()[0] !== '.') {
                $bytes += $item->getSize();
                $files++;
            }
        }
    }
    return ['bytes' => $bytes, 'files' => $files];
}
