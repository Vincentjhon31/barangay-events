<?php
// Release uploads for the download page (https://<site>/download/).
//
// Called ONLY by the release workflow (scripts/publish_release.py) — never by
// the app, the portal, or a person. It has its own secret, separate from
// everything else on the hosting account: private/release-upload-secret.txt
// (one line, at least 32 characters; the same value is the repository's
// RELEASE_UPLOAD_SECRET). Without that file, uploads are switched off.
//
// It can only write inside download/:
//   download/files/e-calendar-X.Y.Z.apk and e-calendar-X.Y.Z-setup.exe
//   download/releases.json  every version, its "What's new" notes, its files
//   download/latest.json    the newest version per platform (the app's update check)
//
//   POST ?action=chunk&name=<file>&offset=<bytes so far>&total=<file size>
//        body = the next piece of the file (at most 8 MB, so it fits the
//        server's request size limit); the file appears once complete.
//   POST ?action=publish   body = JSON, see publish() below.

declare(strict_types=1);
require __DIR__ . '/_lib.php';

const RELEASE_CHUNK_MAX_BYTES = 8 * 1024 * 1024;
const RELEASE_FILE_MAX_BYTES = 400 * 1024 * 1024;
// Older versions keep their notes on the page, but only the newest few keep
// their files, so the folder doesn't grow forever.
const RELEASE_KEEP_FILES = 3;

function require_release_secret(): void
{
    $path = PRIVATE_DIR . '/release-upload-secret.txt';
    $secret = is_file($path) ? trim((string) file_get_contents($path)) : '';
    if (strlen($secret) < 32) {
        fail('Release uploads are not set up on this server.', 503);
    }
    $given = $_SERVER['HTTP_X_RELEASE_SECRET'] ?? '';
    if (!is_string($given) || !hash_equals($secret, $given)) {
        usleep(500000); // slows down guessing
        fail('Not allowed.', 403);
    }
}

function compare_releases(array $a, array $b): int
{
    // Newest first.
    $byVersion = version_compare((string) $b['version'], (string) $a['version']);
    return $byVersion !== 0 ? $byVersion : ((int) ($b['build'] ?? 0)) <=> ((int) ($a['build'] ?? 0));
}

/** Writes [$data] as JSON to [$path] without a half-written moment. */
function write_json_atomically(string $path, array $data): void
{
    $temp = $path . '.tmp';
    $json = json_encode($data, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    if ($json === false || file_put_contents($temp, $json) === false || !rename($temp, $path)) {
        fail('The server could not save the release list.', 500);
    }
}

/** Plain text only: no control characters, bounded length. */
function clean_note($note): ?string
{
    if (!is_string($note)) {
        return null;
    }
    $note = trim((string) preg_replace('/[\x00-\x1F\x7F]+/u', ' ', $note));
    return $note === '' ? null : mb_substr($note, 0, 500);
}

function receive_chunk(): void
{
    $name = (string) ($_GET['name'] ?? '');
    parse_file_name($name);
    $offset = filter_var($_GET['offset'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 0]]);
    $total = filter_var($_GET['total'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1, 'max_range' => RELEASE_FILE_MAX_BYTES]]);
    if ($offset === false || $total === false) {
        fail('Missing or invalid offset/total.', 400);
    }
    $data = (string) file_get_contents('php://input');
    if ($data === '' || strlen($data) > RELEASE_CHUNK_MAX_BYTES) {
        fail('Each piece must be between 1 byte and 8 MB.', 400);
    }

    $dir = download_dir() . '/files';
    ensure_dir($dir);
    $part = $dir . '/' . $name . '.part';
    $have = is_file($part) ? (int) filesize($part) : 0;
    if ($offset === 0) {
        $have = 0; // a fresh start replaces any earlier, unfinished try
    } elseif ($offset !== $have) {
        json_out(['error' => 'Out of order.', 'received' => $have], 409);
    }
    if ($offset + strlen($data) > $total) {
        @unlink($part);
        fail('More data than the stated file size.', 400);
    }
    if (file_put_contents($part, $data, $offset === 0 ? 0 : FILE_APPEND) === false) {
        fail('The server could not save the file.', 500);
    }
    clearstatcache(true, $part);
    $received = (int) filesize($part);
    $complete = $received === $total;
    if ($complete && !rename($part, $dir . '/' . $name)) {
        fail('The server could not save the file.', 500);
    }
    json_out(['received' => $received, 'complete' => $complete]);
}

/**
 * Adds one platform's file to a version and rewrites both lists. Body:
 *   { "version": "1.18.0", "build": 30, "date": "2026-11-05",
 *     "platform": "android" | "windows",
 *     "file": "e-calendar-1.18.0.apk", "size": 66789012, "sha256": "<hex>",
 *     "changelog": { "1.18.0": ["note", ...], "1.17.0": [...], ... } }
 * changelog is every version's "What's new" notes (assets/whats_new.md),
 * so older versions show on the page too, even without files.
 */
function publish(): void
{
    $body = json_decode((string) file_get_contents('php://input'), true);
    if (!is_array($body)) {
        fail('Expected a JSON body.', 400);
    }
    $version = (string) ($body['version'] ?? '');
    $build = filter_var($body['build'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 0]]);
    $date = (string) ($body['date'] ?? '');
    $platform = (string) ($body['platform'] ?? '');
    $file = (string) ($body['file'] ?? '');
    $sha256 = strtolower((string) ($body['sha256'] ?? ''));
    $size = filter_var($body['size'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
    if (!preg_match('/^\d{1,3}\.\d{1,3}\.\d{1,4}$/', $version) || $build === false
        || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) || !isset(RELEASE_PLATFORMS[$platform])
        || !preg_match('/^[0-9a-f]{64}$/', $sha256) || $size === false) {
        fail('Missing or invalid release details.', 400);
    }
    [$fileVersion, $filePlatform] = parse_file_name($file);
    if ($fileVersion !== $version || $filePlatform !== $platform) {
        fail('The file name does not match the version and platform.', 400);
    }

    $dir = download_dir();
    $path = $dir . '/files/' . $file;
    if (!is_file($path) || filesize($path) !== $size || !hash_equals(hash_file('sha256', $path), $sha256)) {
        fail('The uploaded file is missing or does not match its size and checksum.', 409);
    }

    $changelog = [];
    foreach ((is_array($body['changelog'] ?? null) ? $body['changelog'] : []) as $v => $notes) {
        if (count($changelog) >= 200 || !preg_match('/^\d{1,3}\.\d{1,3}\.\d{1,4}$/', (string) $v) || !is_array($notes)) {
            continue;
        }
        $changelog[(string) $v] = array_values(array_filter(array_map('clean_note', array_slice($notes, 0, 30))));
    }

    // The Android and Windows jobs can publish at nearly the same time.
    ensure_dir($dir);
    $lock = fopen($dir . '/.publish.lock', 'c');
    if ($lock === false || !flock($lock, LOCK_EX)) {
        fail('The server is busy. Try again.', 503);
    }

    $listPath = $dir . '/releases.json';
    $existing = is_file($listPath) ? json_decode((string) file_get_contents($listPath), true) : null;
    $byVersion = [];
    foreach ((is_array($existing['releases'] ?? null) ? $existing['releases'] : []) as $entry) {
        if (is_array($entry) && isset($entry['version'])) {
            $byVersion[(string) $entry['version']] = $entry;
        }
    }
    foreach ($changelog as $v => $notes) {
        $byVersion[$v] = ($byVersion[$v] ?? ['version' => $v, 'files' => []]);
        $byVersion[$v]['whats_new'] = $notes;
    }
    $entry = $byVersion[$version] ?? ['version' => $version, 'whats_new' => [], 'files' => []];
    $entry['build'] = $build;
    $entry['date'] = $date;
    $entry['files'] = is_array($entry['files'] ?? null) ? $entry['files'] : [];
    $entry['files'][$platform] = [
        'name' => $file,
        'size' => $size,
        'sha256' => $sha256,
        'url' => download_public_url() . '/files/' . rawurlencode($file),
    ];
    $byVersion[$version] = $entry;

    $releases = array_values($byVersion);
    usort($releases, 'compare_releases');

    // Keep the files of the newest few versions per platform only.
    $kept = array_fill_keys(array_keys(RELEASE_PLATFORMS), 0);
    foreach ($releases as $i => $release) {
        foreach (array_keys(RELEASE_PLATFORMS) as $p) {
            if (!isset($release['files'][$p])) {
                continue;
            }
            if (++$kept[$p] > RELEASE_KEEP_FILES) {
                @unlink($dir . '/files/' . basename((string) $release['files'][$p]['name']));
                unset($releases[$i]['files'][$p]);
            }
        }
    }

    $now = gmdate('c');
    // (object): a version without files must still be {} in JSON, not [].
    $listed = array_map(fn (array $r): array => array_merge($r, ['files' => (object) ($r['files'] ?? [])]), $releases);
    write_json_atomically($listPath, ['updated_at' => $now, 'releases' => $listed]);

    $latest = ['updated_at' => $now, 'page' => download_public_url() . '/'];
    foreach (array_keys(RELEASE_PLATFORMS) as $p) {
        $latest[$p] = null;
        foreach ($releases as $release) {
            if (isset($release['files'][$p])) {
                $latest[$p] = [
                    'version' => $release['version'],
                    'build' => $release['build'] ?? 0,
                    'date' => $release['date'] ?? null,
                    'whats_new' => $release['whats_new'] ?? [],
                    // Counted (api/download.php), then on to `url`.
                    'download' => rtrim(API_PUBLIC_URL, '/') . '/download.php?file=' . rawurlencode((string) $release['files'][$p]['name']),
                ] + $release['files'][$p];
                break;
            }
        }
    }
    write_json_atomically($dir . '/latest.json', $latest);

    flock($lock, LOCK_UN);
    fclose($lock);
    json_out(['ok' => true, 'version' => $version, 'platform' => $platform, 'latest' => $latest[$platform]]);
}

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    fail('Not found.', 404);
}
require_release_secret();
match ($_GET['action'] ?? '') {
    'chunk' => receive_chunk(),
    'publish' => publish(),
    default => fail('Unknown action.', 400),
};
