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
