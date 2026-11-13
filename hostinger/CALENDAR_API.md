# eBongabong Calendar API — guide for developers

The eBongabong Calendar is the LGU's main calendar. This API lets another LGU system (for example the intranet website) **read** its events as JSON, so there's one calendar for the whole LGU instead of two. It's read-only: events are still created and edited in the eCalendar app or the admin portal.

## What you need

- **An API key** from the eCalendar superadmin (made on the admin portal's **API** page). It looks like `ecal_` followed by 64 letters and numbers.
- Treat it like a password. Keep it in your server's settings (an environment variable or config file outside the web root), **not** in browser JavaScript or a public repository, and don't paste it into chats.
- One key per system. If a key leaks, ask the superadmin to revoke it and make a new one; the old one stops working immediately.

## The request

```
GET https://calendar.bongabong.gov.ph/api/events.php
X-API-Key: ecal_...
```

The key can also be sent as `Authorization: Bearer ecal_...`, or as `?key=ecal_...` for a quick test in a browser (avoid that one in real code: addresses end up in logs and browser history).

### Parameters (all optional)

| Parameter | Meaning |
|---|---|
| `from`, `to` | Dates like `2026-11-30` (Philippine dates, both included). Events that overlap the range are returned. Default: today to 30 days ahead. At most 366 days per request. |
| `type` | `public`, `calendar`, or `group` — only that kind of event. |
| `calendar` | Only one calendar, by its id (get ids from `?action=calendars`). |
| `id` | One event by its id. Returns `{"event": {...}}`. |
| `action=calendars` | Instead of events: what this key can read (`public_events` true/false, the `calendars` list with id, name, color, icon, archived, and the `groups` list with id and name). |
| `limit`, `offset` | Paging: up to 1000 events per request (500 if not given). `has_more: true` means ask again with `offset` increased by `limit`. |
| `pretty=1` | Indented JSON, easier to read. |

## What comes back

```json
{
  "api_version": 1,
  "generated_at": "2026-11-06T14:06:47+08:00",
  "timezone": "Asia/Manila",
  "from": "2026-11-01",
  "to": "2026-11-30",
  "count": 1,
  "offset": 0,
  "limit": 500,
  "has_more": false,
  "events": [
    {
      "id": "1730000000000001",
      "title": "Municipal Foundation Day",
      "description": "Program at the plaza",
      "location": "Municipal Plaza",
      "start": "2026-11-07T08:00:00+08:00",
      "end": "2026-11-07T17:00:00+08:00",
      "all_day": false,
      "days": [
        { "date": "2026-11-07", "start": "2026-11-07T08:00:00+08:00", "end": "2026-11-07T17:00:00+08:00", "all_day": false }
      ],
      "type": "public",
      "calendar": null,
      "group": null,
      "color": "#2B8FD6",
      "contact_number": null,
      "posted_by": { "name": "Juan Dela Cruz", "office": "Office of the Municipal Mayor" },
      "posted_at": "2026-11-01T09:30:00+08:00",
      "series_id": null
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `id` | The event's id (text). |
| `title`, `description` | `description` is `""` when empty. |
| `location` | `null` when no venue was given. |
| `start`, `end` | ISO 8601 with the Philippine offset (`+08:00`). Any language's date parser reads these as the correct moment. |
| `all_day` | `true` for all-day events (stored as 00:00 to 23:59). |
| `days` | One entry per calendar day the event covers, each with that day's own `start`, `end` and `all_day`. **Use this to draw events that span several days**: in eCalendar, a 3-day event from 8:00 to 12:00 means 8:00–12:00 on each of the three days (not 72 hours straight), and a day can have its own hours. An event whose end time is earlier than its start time (e.g. 22:00 to 02:00 the next day) is one continuous stretch, and `days` shows it that way. |
| `type` | `public`; `calendar` for an event in one of the LGU's calendars (e.g. Sports); or `group` for an event of a group the superadmin let this key read. |
| `calendar` | For calendar events: `{"id", "name"}`; otherwise `null`. |
| `group` | For group events: `{"id", "name"}`; otherwise `null`. |
| `color` | The event's color label as hex (calendar events without their own color use the calendar's), or `null`. |
| `contact_number` | Or `null`. |
| `posted_by` | `{"name", "office"}` of who posted it; either can be `null`. |
| `posted_at` | When it was posted (`+08:00`). |
| `series_id` | Events held on several separate dates (e.g. every Saturday of a month) come as one entry per date, and those entries share the same `series_id`. `null` for ordinary events. |

Events come oldest first (by start). New fields may be added in later versions; existing ones won't change meaning without a new `api_version`.

**Never included:** personal events, and events of groups the superadmin didn't tick for your key. A key can be limited further (e.g. only the Sports calendar); `?action=calendars` shows what yours can read.

## Errors

Errors come back as JSON with a code and a readable message:

```json
{ "error": { "code": "invalid_api_key", "message": "This API key isn't valid. It may have been revoked, or not copied completely." } }
```

| HTTP | `code` | What to do |
|---|---|---|
| 400 | `invalid_parameter` | A parameter is wrong; the message says which. |
| 401 | `missing_api_key` / `invalid_api_key` | Send the key; check it's complete and not revoked. |
| 404 | `not_found` | No event with that `id` that your key can read. |
| 405 | `method_not_allowed` | Only `GET` is supported. |
| 429 | `rate_limited` | More than 300 requests in a minute with one key. Wait the seconds in the `Retry-After` header. |
| 502 / 503 | `database_unreachable`, `database_error`, `not_set_up` | A problem on the calendar's side. Try again later, and keep showing your last good copy meanwhile. |

## Good practice

- **Cache.** Fetch on your server every few minutes and serve your pages from that copy, instead of calling the API on every page view. It's faster for your visitors and keeps you far below the rate limit.
- Ask for the range you show (e.g. this month) rather than a whole year at a time.
- Show `days` for multi-day events, and display times in Philippine time.

## Examples

**curl**

```
curl -H "X-API-Key: $ECAL_API_KEY" "https://calendar.bongabong.gov.ph/api/events.php?from=2026-11-01&to=2026-11-30"
```

**JavaScript (server side, Node 18+)**

```js
const url = 'https://calendar.bongabong.gov.ph/api/events.php?from=2026-11-01&to=2026-11-30';
const res = await fetch(url, { headers: { 'X-API-Key': process.env.ECAL_API_KEY } });
const body = await res.json();
if (!res.ok) throw new Error(body.error.message);
for (const event of body.events) {
  console.log(event.title, event.start, event.location ?? '');
}
```

**PHP**

```php
$url = 'https://calendar.bongabong.gov.ph/api/events.php?from=2026-11-01&to=2026-11-30';
$context = stream_context_create(['http' => [
    'header' => 'X-API-Key: ' . getenv('ECAL_API_KEY'),
    'ignore_errors' => true,   // still read the JSON on 4xx/5xx
]]);
$body = json_decode((string) file_get_contents($url, false, $context), true);
if (isset($body['error'])) {
    throw new RuntimeException($body['error']['message']);
}
foreach ($body['events'] as $event) {
    echo $event['title'], ' — ', $event['start'], PHP_EOL;
}
```

**Python**

```python
import os, requests
r = requests.get('https://calendar.bongabong.gov.ph/api/events.php',
                 params={'from': '2026-11-01', 'to': '2026-11-30'},
                 headers={'X-API-Key': os.environ['ECAL_API_KEY']}, timeout=20)
r.raise_for_status()
for event in r.json()['events']:
    print(event['title'], event['start'])
```

Browsers may call the API directly too (it allows any origin), but then visitors can read the key from your page. Only do that if the superadmin agrees, ideally with a key limited to what that page shows.

## For eCalendar maintainers

- Endpoint: `hostinger/public_html/api/events.php`. Database side: the "Calendar API" block at the end of `supabase/barangay_events.sql` (`api_keys`, `api_list_events`, `api_list_calendars`, `admin_*_api_key`, `admin_list_groups`). Portal: the API page in `docs/lgu-admin/index.html`.
- Keys are checked in the database; Hostinger still holds only the public publishable key. Requests are checked against each key's SHA-256 hash; the key itself is kept encrypted in Supabase Vault so the superadmin can copy it again from the portal (deleted from Vault on revoke). Keys made before that change have no kept copy. API keys aren't in backups — after a restore onto a new back end, make new keys.
- Tests: `python hostinger/tests/run_tests.py` (PHP side) and `supabase/tests/calendar_api.test.mjs` (SQL side, see the file's header).
