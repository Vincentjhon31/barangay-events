<?php
// The download page's buttons and the app's update prompt go through here,
// so downloads can be counted (the store page shows the total), then on to
// the file itself in download/files/. No sign-in: the files are public.
//
//   GET ?file=e-calendar-1.18.0.apk   counts it, then redirects to the file
//   GET ?action=stats                 {"android": n, "windows": n, "total": n}
//
// Counts are kept in private/download-counts.json. DOWNLOADS_BEFORE_MOVE in
// api-config.php (optional) adds the downloads made from GitHub before the
// download page moved here, so the total doesn't start over at zero.

declare(strict_types=1);
require __DIR__ . '/_lib.php';
cors();

function counts_path(): string
{
    return PRIVATE_DIR . '/download-counts.json';
}

/** Runs [$change] on the counts while holding the file lock; returns them. */
function with_counts(?callable $change): array
{
    $handle = @fopen(counts_path(), 'c+');
    if ($handle === false) {
        return ['android' => 0, 'windows' => 0];
    }
    flock($handle, $change === null ? LOCK_SH : LOCK_EX);
    $counts = json_decode((string) stream_get_contents($handle), true);
    $counts = [
        'android' => (int) ($counts['android'] ?? 0),
        'windows' => (int) ($counts['windows'] ?? 0),
    ];
    if ($change !== null) {
        $counts = $change($counts);
        ftruncate($handle, 0);
        rewind($handle);
        fwrite($handle, (string) json_encode($counts));
        fflush($handle);
    }
    flock($handle, LOCK_UN);
    fclose($handle);
    return $counts;
}

if (($_GET['action'] ?? '') === 'stats') {
    $counts = with_counts(null);
    $before = defined('DOWNLOADS_BEFORE_MOVE') ? (int) constant('DOWNLOADS_BEFORE_MOVE') : 0;
    // Public numbers: the store page may live on another site.
    header('Access-Control-Allow-Origin: *');
    header('Cache-Control: no-cache');
    json_out($counts + ['total' => $counts['android'] + $counts['windows'] + $before]);
}

$name = (string) ($_GET['file'] ?? '');
if (!preg_match(RELEASE_FILE_PATTERN, $name) || !is_file(download_dir() . '/files/' . $name)) {
    // An old or mistyped link: send people to the page with the current files.
    header('Location: ' . download_public_url() . '/', true, 302);
    exit;
}
[, $platform] = parse_file_name($name);
with_counts(function (array $counts) use ($platform): array {
    $counts[$platform]++;
    return $counts;
});
header('Cache-Control: no-store');
header('Location: ' . download_public_url() . '/files/' . rawurlencode($name), true, 302);
exit;
