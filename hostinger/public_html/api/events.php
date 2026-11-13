<?php
// The calendar API: lets another LGU system (e.g. the intranet website)
// read the calendar's events as JSON, with an API key the superadmin makes
// on the portal's API page. Read-only, and only Public events and the
// custom calendars (e.g. Sports) — never Group or Personal events.
//
//   GET events.php?from=2026-11-01&to=2026-11-30   events on those dates
//   GET events.php?id=<event id>                    one event
//   GET events.php?action=calendars                 what the key can read
//
// The key goes in an "X-API-Key" header ("Authorization: Bearer <key>" and
// "?key=<key>" work too). Optional: type=public|calendar|group, calendar=<id>,
// limit (1-1000, default 500), offset, pretty=1. Full guide for developers:
// hostinger/CALENDAR_API.md.
//
// The key is checked inside Supabase (api_list_events / api_list_calendars,
// "Calendar API" block in supabase/barangay_events.sql), which this server
// calls with the public publishable key only — still no secret on Hostinger.

declare(strict_types=1);
require __DIR__ . '/_lib.php';

const CALENDAR_API_VERSION = 1;
const API_KEY_PATTERN = '/^ecal_[0-9a-f]{64}$/';

// Any website may call this from a browser: the API key, not the page's
// address, is what grants access, and no cookies are involved.
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: X-API-Key, Authorization');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Expose-Headers: Retry-After');
header('Access-Control-Max-Age: 86400');
header('X-Content-Type-Options: nosniff');

function api_out(array $data, int $status = 200): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    $flags = JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE;
    $pretty = $_GET['pretty'] ?? '';
    if (is_string($pretty) && $pretty !== '' && $pretty !== '0') {
        $flags |= JSON_PRETTY_PRINT;
    }
    echo json_encode($data, $flags);
    exit;
}

function api_error(int $status, string $code, string $message): void
{
    api_out(['error' => ['code' => $code, 'message' => $message]], $status);
}

/** A query parameter as a trimmed string ('' if missing; 400 if it's a list). */
function param(string $name): string
{
    $value = $_GET[$name] ?? '';
    if (!is_string($value)) {
        api_error(400, 'invalid_parameter', '"' . $name . '" must be given once.');
    }
    return trim($value);
}

function date_param(string $name): ?string
{
    $value = param($name);
    if ($value === '') {
        return null;
    }
    if (!preg_match('/^([0-9]{4})-([0-9]{2})-([0-9]{2})$/', $value, $m) || !checkdate((int) $m[2], (int) $m[3], (int) $m[1])) {
        api_error(400, 'invalid_parameter', '"' . $name . '" must be a date like 2026-11-30.');
    }
    return $value;
}

function int_param(string $name, int $min, int $max): ?int
{
    $value = param($name);
    if ($value === '') {
        return null;
    }
    if (!ctype_digit($value) || strlen($value) > 6 || (int) $value < $min || (int) $value > $max) {
        api_error(400, 'invalid_parameter', '"' . $name . '" must be a whole number from ' . $min . ' to ' . $max . '.');
    }
    return (int) $value;
}

/** The API key from the X-API-Key header, a Bearer token, or ?key=. */
function api_key(): ?string
{
    $candidates = [$_SERVER['HTTP_X_API_KEY'] ?? null];
    $authorization = [$_SERVER['HTTP_AUTHORIZATION'] ?? null, $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? null];
    if (function_exists('getallheaders')) {
        foreach (getallheaders() as $name => $value) {
            if (strcasecmp((string) $name, 'X-API-Key') === 0) {
                $candidates[] = $value;
            } elseif (strcasecmp((string) $name, 'Authorization') === 0) {
                $authorization[] = $value;
            }
        }
    }
    foreach ($authorization as $value) {
        if (is_string($value) && preg_match('/^Bearer\s+(\S+)$/i', trim($value), $m)) {
            $candidates[] = $m[1];
        }
    }
    $candidates[] = $_GET['key'] ?? null;
    foreach ($candidates as $candidate) {
        if (is_string($candidate) && trim($candidate) !== '') {
            return trim($candidate);
        }
    }
    return null;
}

/** Calls one of the API's database functions; stops with the right error. */
function call_api(string $function, array $params): array
{
    $res = supabase_request('POST', '/rest/v1/rpc/' . $function, null, $params);
    if ($res['status'] === 200 && is_array($res['data'])) {
        return $res['data'];
    }
    $body = is_array($res['data']) ? $res['data'] : [];
    $message = (string) ($body['message'] ?? '');
    if ($message === 'invalid_api_key') {
        api_error(401, 'invalid_api_key', 'This API key isn\'t valid. It may have been revoked, or not copied completely.');
    }
    if ($message === 'rate_limited') {
        $wait = (int) ($body['hint'] ?? 60);
        header('Retry-After: ' . max(1, min(60, $wait)));
        api_error(429, 'rate_limited', 'Too many requests with this key in the last minute. Wait a moment, and keep a copy of results instead of asking again on every page view.');
    }
    if ($message === 'not_found') {
        api_error(404, 'not_found', 'There is no event with that id that this key can read.');
    }
    if ($message === 'invalid_parameter') {
        api_error(400, 'invalid_parameter', (string) ($body['details'] ?? 'One of the parameters isn\'t valid.'));
    }
    $code = (string) ($body['code'] ?? '');
    if ($code === 'PGRST202' || $code === '42883') {
        api_error(503, 'not_set_up', 'The calendar API isn\'t switched on yet on the server.');
    }
    if ($res['status'] === 0) {
        api_error(502, 'database_unreachable', 'The calendar database couldn\'t be reached. Try again shortly.');
    }
    api_error(502, 'database_error', 'The calendar database had a problem answering. Try again shortly.');
    return [];
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
if ($method === 'OPTIONS') {
    http_response_code(204);
    exit;
}
if ($method !== 'GET' && $method !== 'HEAD') {
    header('Allow: GET, OPTIONS');
    api_error(405, 'method_not_allowed', 'The calendar API only answers GET requests.');
}

$key = api_key();
if ($key === null) {
    api_error(401, 'missing_api_key', 'Send your API key in an X-API-Key header.');
}
if (!preg_match(API_KEY_PATTERN, $key)) {
    api_error(401, 'invalid_api_key', 'This API key isn\'t valid. It may have been revoked, or not copied completely.');
}

$action = param('action');
if ($action === 'calendars') {
    $data = call_api('api_list_calendars', ['p_key' => $key]);
} elseif ($action === '') {
    $params = ['p_key' => $key];
    $id = param('id');
    if ($id !== '') {
        if (!preg_match('/^[A-Za-z0-9_-]{1,64}$/', $id)) {
            api_error(400, 'invalid_parameter', '"id" isn\'t an event id.');
        }
        $params['p_event_id'] = $id;
    } else {
        $from = date_param('from');
        $to = date_param('to');
        if ($from !== null) {
            $params['p_from'] = $from;
        }
        if ($to !== null) {
            $params['p_to'] = $to;
        }
        $type = param('type');
        if ($type !== '') {
            if (!in_array($type, ['public', 'calendar', 'group'], true)) {
                api_error(400, 'invalid_parameter', '"type" must be public, calendar, or group.');
            }
            $params['p_type'] = $type;
        }
        $calendar = param('calendar');
        if ($calendar !== '') {
            if (!is_uuid($calendar)) {
                api_error(400, 'invalid_parameter', '"calendar" must be a calendar id from ?action=calendars.');
            }
            $params['p_calendar_id'] = strtolower($calendar);
        }
        $limit = int_param('limit', 1, 1000);
        if ($limit !== null) {
            $params['p_limit'] = $limit;
        }
        $offset = int_param('offset', 0, 100000);
        if ($offset !== null) {
            $params['p_offset'] = $offset;
        }
    }
    $data = call_api('api_list_events', $params);
} else {
    api_error(400, 'invalid_parameter', '"action" can only be calendars.');
}

api_out([
    'api_version' => CALENDAR_API_VERSION,
    'generated_at' => (new DateTimeImmutable('now', new DateTimeZone('Asia/Manila')))->format('c'),
    'timezone' => 'Asia/Manila',
] + $data);
