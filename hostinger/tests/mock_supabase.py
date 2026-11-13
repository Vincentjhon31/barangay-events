"""A tiny stand-in for the Supabase endpoints the file API calls, with the
same permission rules (RLS) the real database applies — for testing the PHP
API locally. Not for production; see run_tests.py."""
import json
import re
import sys
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

POSTER = 'aaaaaaaa-0000-4000-8000-000000000001'
OTHER = 'aaaaaaaa-0000-4000-8000-000000000002'
SUPER = 'aaaaaaaa-0000-4000-8000-000000000003'
TOKENS = {'tok-poster': POSTER, 'tok-other': OTHER, 'tok-super': SUPER}

STATE = {
    'profiles': {
        POSTER: {'role': 'citizen', 'avatar_url': None},
        OTHER: {'role': 'citizen', 'avatar_url': None},
        SUPER: {'role': 'superadmin', 'avatar_url': None},
    },
    # event id -> creator; 'ev-private' is only visible to its creator.
    'events': {'ev1': POSTER, 'ev-private': POSTER},
    'attachments': [],
    'presets': [],
}


# Calendar API keys (api_list_events / api_list_calendars). The real checks
# live in the database; this only plays back what it answers.
API_KEY_OK = 'ecal_' + 'a' * 64
API_KEYS = {
    API_KEY_OK: 'ok',
    'ecal_' + 'b' * 64: 'rate_limited',
    'ecal_' + 'c' * 64: 'not_set_up',
    'ecal_' + 'd' * 64: 'revoked',
}
SPORTS = '10000000-0000-4000-8000-000000000001'
SAMPLE_EVENT = {
    'id': '1730000000000001', 'title': 'Foundation Day', 'description': 'Program at the plaza', 'location': 'Municipal Plaza',
    'start': '2026-11-07T10:00:00+08:00', 'end': '2026-11-07T12:00:00+08:00', 'all_day': False,
    'days': [{'date': '2026-11-07', 'start': '2026-11-07T10:00:00+08:00', 'end': '2026-11-07T12:00:00+08:00', 'all_day': False}],
    'type': 'public', 'calendar': None, 'color': None, 'contact_number': None,
    'posted_by': {'name': 'Ana Cruz', 'office': 'MDRRMO'}, 'posted_at': '2026-11-01T09:30:00+08:00', 'series_id': None,
}
API_CALLS = []


def eq(query, field):
    values = query.get(field)
    if not values:
        return None
    m = re.match(r'^eq\.(.*)$', values[0])
    return m.group(1) if m else None


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def caller(self):
        auth = self.headers.get('Authorization', '')
        token = auth[7:] if auth.startswith('Bearer ') else None
        return TOKENS.get(token)

    def body(self):
        length = int(self.headers.get('Content-Length') or 0)
        return json.loads(self.rfile.read(length) or b'null') if length else None

    def send(self, status, data=None):
        raw = b'' if data is None else json.dumps(data).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def visible_event(self, event_id, uid):
        creator = STATE['events'].get(event_id)
        if creator is None:
            return False
        return event_id != 'ev-private' or creator == uid

    def handle_any(self, method):
        url = urlparse(self.path)
        q = parse_qs(url.query)
        uid = self.caller()
        path = url.path

        if path == '/auth/v1/user':
            return self.send(200, {'id': uid}) if uid else self.send(401, {'message': 'invalid JWT'})

        # The calendar API is called without a login (as anon).
        if path in ('/rest/v1/rpc/api_list_events', '/rest/v1/rpc/api_list_calendars') and method == 'POST':
            body = self.body() or {}
            API_CALLS.append({'path': path, 'body': body, 'authorization': self.headers.get('Authorization'),
                              'apikey': self.headers.get('apikey')})
            kind = API_KEYS.get(body.get('p_key'))
            if kind == 'not_set_up':
                return self.send(404, {'code': 'PGRST202', 'message': 'Could not find the function public.' + path.rsplit('/', 1)[1]})
            if kind in (None, 'revoked'):
                return self.send(401, {'code': 'PT401', 'message': 'invalid_api_key', 'details': None, 'hint': None})
            if kind == 'rate_limited':
                return self.send(429, {'code': 'PT429', 'message': 'rate_limited', 'details': None, 'hint': '42'})
            if path.endswith('api_list_calendars'):
                return self.send(200, {'public_events': True, 'calendars': [
                    {'id': SPORTS, 'name': 'Sports', 'color': '#2FA36B', 'icon': 'basketball', 'archived': False}]})
            if body.get('p_event_id') == 'missing':
                return self.send(404, {'code': 'PT404', 'message': 'not_found', 'details': None, 'hint': None})
            if body.get('p_event_id'):
                return self.send(200, {'event': SAMPLE_EVENT})
            if body.get('p_from') and body.get('p_to') and body['p_to'] < body['p_from']:
                return self.send(400, {'code': 'PT400', 'message': 'invalid_parameter', 'details': '"to" is before "from".', 'hint': None})
            return self.send(200, {'from': body.get('p_from', '2026-11-06'), 'to': body.get('p_to', '2026-12-06'), 'count': 1,
                                   'offset': body.get('p_offset', 0), 'limit': body.get('p_limit', 500), 'has_more': False,
                                   'events': [SAMPLE_EVENT]})
        if path == '/__api_calls':
            return self.send(200, API_CALLS)

        if uid is None:
            return self.send(401, {'message': 'JWT required'})

        if path == '/rest/v1/profiles':
            target = eq(q, 'id')
            if method == 'GET':
                return self.send(200, [{'role': STATE['profiles'][target]['role']}] if target == uid else [])
            if method == 'PATCH':
                if target != uid:
                    return self.send(200, [])
                STATE['profiles'][uid].update(self.body())
                return self.send(204)

        if path == '/rest/v1/barangay_events' and method == 'GET':
            event_id = eq(q, 'id')
            if not self.visible_event(event_id, uid):
                return self.send(200, [])
            return self.send(200, [{'id': event_id, 'created_by_id': STATE['events'][event_id]}])

        if path == '/rest/v1/event_attachments':
            if method == 'GET':
                rows = [r for r in STATE['attachments'] if self.visible_event(r['event_id'], uid)]
                if eq(q, 'event_id'):
                    rows = [r for r in rows if r['event_id'] == eq(q, 'event_id')]
                if eq(q, 'id'):
                    rows = [r for r in rows if r['id'] == eq(q, 'id')]
                return self.send(200, rows)
            if method == 'POST':
                row = self.body()
                if STATE['events'].get(row['event_id']) != uid:
                    return self.send(403, {'message': 'new row violates row-level security policy'})
                row['id'] = str(uuid.uuid4())
                STATE['attachments'].append(row)
                return self.send(201, [row])
            if method == 'DELETE':
                target = eq(q, 'id')
                rows = [r for r in STATE['attachments'] if r['id'] == target and STATE['events'].get(r['event_id']) == uid]
                STATE['attachments'] = [r for r in STATE['attachments'] if r not in rows]
                return self.send(200, rows)

        if path == '/rest/v1/avatar_presets':
            if STATE['profiles'][uid]['role'] != 'superadmin':
                return self.send(403, {'message': 'new row violates row-level security policy'})
            if method == 'POST':
                row = self.body()
                row['id'] = str(uuid.uuid4())
                STATE['presets'].append(row)
                return self.send(201, [row])
            if method == 'DELETE':
                target = eq(q, 'id')
                rows = [r for r in STATE['presets'] if r['id'] == target]
                STATE['presets'] = [r for r in STATE['presets'] if r not in rows]
                return self.send(200, rows)

        if path == '/rest/v1/rpc/admin_reset_avatar' and method == 'POST':
            if STATE['profiles'][uid]['role'] != 'superadmin':
                return self.send(400, {'message': 'Only a superadmin can remove profile pictures'})
            STATE['profiles'][self.body()['p_user_id']]['avatar_url'] = None
            return self.send(204)

        if path == '/__state':
            return self.send(200, STATE)
        return self.send(404, {'message': 'not mocked: ' + method + ' ' + path})

    def do_GET(self):
        self.handle_any('GET')

    def do_POST(self):
        self.handle_any('POST')

    def do_PATCH(self):
        self.handle_any('PATCH')

    def do_DELETE(self):
        self.handle_any('DELETE')


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8798
    ThreadingHTTPServer(('127.0.0.1', port), Handler).serve_forever()
