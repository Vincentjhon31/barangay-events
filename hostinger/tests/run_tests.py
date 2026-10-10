"""End-to-end tests for the Hostinger file API, run locally:

    python hostinger/tests/run_tests.py

Copies the API into a temporary folder laid out like the Hostinger server,
points it at mock_supabase.py instead of the real Supabase, starts PHP's
built-in web server, and exercises every endpoint. Needs PHP 8 (with gd,
curl, fileinfo) on PATH. Doesn't touch Hostinger or Supabase.

Note: PHP's built-in server ignores .htaccess files, so those rules (no
directory listings, no scripts in media/) are only active on Hostinger."""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.dirname(HERE)
MOCK_PORT = 8798
PHP_PORT = 8799
# A second copy of the site server, so the health check can try to read
# private/ over HTTP (PHP's built-in server handles one request at a time,
# so it can't call itself).
PROBE_PORT = 8800
API = f'http://127.0.0.1:{PHP_PORT}/api'

failures = []


def check(name, condition, detail=''):
    print(('PASS ' if condition else 'FAIL ') + name + ('' if condition else f'  -> {detail}'))
    if not condition:
        failures.append(name)


def request(method, url, token=None, fields=None, files=None, headers=None):
    body = None
    hdrs = dict(headers or {})
    if token:
        hdrs['Authorization'] = 'Bearer ' + token
    if fields is not None or files is not None:
        boundary = uuid.uuid4().hex
        parts = []
        for k, v in (fields or {}).items():
            parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode())
        for k, (filename, data, ctype) in (files or {}).items():
            parts.append(
                f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"; filename="{filename}"\r\n'
                f'Content-Type: {ctype}\r\n\r\n'.encode() + data + b'\r\n')
        parts.append(f'--{boundary}--\r\n'.encode())
        body = b''.join(parts)
        hdrs['Content-Type'] = f'multipart/form-data; boundary={boundary}'
    req = urllib.request.Request(url, data=body, method=method, headers=hdrs)
    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            return res.status, res.read(), dict(res.headers)
    except urllib.error.HTTPError as e:
        return e.code, e.read(), dict(e.headers)


def jbody(raw):
    try:
        return json.loads(raw)
    except Exception:
        return {'raw': raw[:200]}


def php(code):
    return subprocess.run(['php', '-r', code], capture_output=True, check=True).stdout


def main():
    # Laid out like the subdomain's own folder on Hostinger ("calendar"):
    # api/, media/ and private/ all inside the site folder.
    root = tempfile.mkdtemp(prefix='hostinger-test-')
    site = os.path.join(root, 'calendar')
    shutil.copytree(os.path.join(SRC, 'public_html'), site)
    shutil.copytree(os.path.join(SRC, 'private'), os.path.join(site, 'private'))
    with open(os.path.join(SRC, 'private', 'api-config.example.php'), encoding='utf-8') as f:
        config = f.read()
    config = config.replace('https://xuxnoydakqembrytdbyz.supabase.co', f'http://127.0.0.1:{MOCK_PORT}')
    config = config.replace('https://calendar.bongabong.gov.ph/api', API)
    config = config.replace('https://calendar.bongabong.gov.ph/media', f'http://127.0.0.1:{PHP_PORT}/media')
    config = config.replace('https://calendar.bongabong.gov.ph/private', f'http://127.0.0.1:{PROBE_PORT}/private')
    with open(os.path.join(site, 'private', 'api-config.php'), 'w', encoding='utf-8') as f:
        f.write(config)
    uploads = os.path.join(site, 'private', 'uploads')
    media = os.path.join(site, 'media')

    mock = subprocess.Popen([sys.executable, os.path.join(HERE, 'mock_supabase.py'), str(MOCK_PORT)])
    server = subprocess.Popen(['php', '-S', f'127.0.0.1:{PHP_PORT}', '-t', site],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    probe = subprocess.Popen(['php', '-S', f'127.0.0.1:{PROBE_PORT}', '-t', site],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1.5)
    try:
        png = php('$i=imagecreatetruecolor(800,600);imagefill($i,0,0,imagecolorallocate($i,30,120,200));ob_start();imagepng($i);echo ob_get_clean();')
        pdf = b'%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n'
        fake = b'<?php echo "pwned"; ?>'

        s, b, _ = request('GET', API + '/')
        health = jbody(b)
        check('health check runs', s == 200 and health.get('gd') is True and health.get('uploads_writable') is True, b)
        # PHP's test server ignores .htaccess, so private/ IS readable here —
        # the health check must notice and say so (on Hostinger it's true).
        check('health check detects an unprotected private folder',
              health.get('private_protected') is False and health.get('ok') is False and 'warning' in health, b)

        # ---------- CORS (browser callers) ----------
        def preflight(origin):
            _, _, h = request('OPTIONS', API + '/avatars.php', headers={
                'Origin': origin, 'Access-Control-Request-Method': 'POST',
                'Access-Control-Request-Headers': 'authorization,x-auth-token'})
            return {k.lower(): v for k, v in h.items()}.get('access-control-allow-origin')
        check('Flutter web debug (localhost, any port) may call the API', preflight('http://localhost:16690') == 'http://localhost:16690')
        check('127.0.0.1 with a port may call the API', preflight('http://127.0.0.1:5500') == 'http://127.0.0.1:5500')
        check('the live web app may call the API', preflight('https://calendar.bongabong.gov.ph') == 'https://calendar.bongabong.gov.ph')
        check("a stranger's website may not", preflight('https://evil.example') is None)
        check('a look-alike localhost domain may not', preflight('http://localhost.evil.example') is None)

        # ---------- Attachments ----------
        s, b, _ = request('POST', API + '/attachments.php', fields={'event_id': 'ev1'}, files={'file': ('a.png', png, 'image/png')})
        check('upload needs a login', s == 401, (s, b))
        s, b, _ = request('POST', API + '/attachments.php', 'tok-bogus', fields={'event_id': 'ev1'}, files={'file': ('a.png', png, 'image/png')})
        check('upload rejects an invalid token', s == 401, (s, b))
        s, b, _ = request('POST', API + '/attachments.php', 'tok-other', fields={'event_id': 'ev1'}, files={'file': ('a.png', png, 'image/png')})
        check("only the event's poster can attach", s == 403, (s, b))
        s, b, _ = request('POST', API + '/attachments.php', 'tok-poster', fields={'event_id': 'ev1'}, files={'file': ('Agenda photo.png', png, 'image/png')})
        row = jbody(b)
        check('poster uploads a picture', s == 201 and row.get('storage_provider') == 'hostinger' and row.get('mime_type') == 'image/png', (s, b))
        stored = os.path.join(uploads, row.get('storage_path', 'missing').replace('/', os.sep))
        check('file is stored in the private folder', os.path.isfile(stored) and os.sep + 'private' + os.sep in stored, stored)
        check('original file name is kept for display', row.get('file_name') == 'Agenda photo.png', row.get('file_name'))
        s, b, _ = request('POST', API + '/attachments.php', 'tok-poster', fields={'event_id': 'ev1'}, files={'file': ('evil.jpg', fake, 'image/jpeg')})
        check('a script disguised as a picture is refused', s == 415, (s, b))
        s, b, _ = request('POST', API + '/attachments.php', 'tok-poster', fields={'event_id': '../etc'}, files={'file': ('a.png', png, 'image/png')})
        check('a path-like event id is refused', s == 400, (s, b))
        s, b, _ = request('POST', API + '/attachments.php', 'tok-poster', fields={'event_id': 'ev1'}, files={'file': ('Minutes.pdf', pdf, 'application/pdf')})
        pdf_row = jbody(b)
        check('a PDF is accepted', s == 201 and pdf_row.get('mime_type') == 'application/pdf', (s, b))

        s, b, h = request('GET', API + '/attachments.php?id=' + row['id'], 'tok-other')
        check('anyone who can see the event can download', s == 200 and b == png and h.get('Content-Type', '').startswith('image/png'), (s, h.get('Content-Type')))
        s, b, _ = request('GET', API + '/attachments.php?id=' + row['id'])
        check('download needs a login', s == 401, (s, b))

        s, b, _ = request('GET', API + '/attachments.php?action=link&id=' + pdf_row['id'], 'tok-other')
        link = jbody(b).get('url', '')
        check('a signed link is issued', s == 200 and link.startswith(API + '/attachments.php?'), (s, b))
        s, b, h = request('GET', link)
        check('the signed link opens without a login', s == 200 and b == pdf, (s, h.get('Content-Type')))
        s, b, _ = request('GET', link.replace('sig=', 'sig=0'))
        check('a tampered signed link is refused', s == 403, (s, b))

        # Private event: its attachments stay hidden from others.
        STATE_private = request('POST', API + '/attachments.php', 'tok-poster', fields={'event_id': 'ev-private'}, files={'file': ('p.png', png, 'image/png')})
        priv = jbody(STATE_private[1])
        s, b, _ = request('GET', API + '/attachments.php?id=' + priv.get('id', ''), 'tok-other')
        check("a file on an event you can't see stays hidden", s == 404, (s, b))

        s, b, _ = request('DELETE', API + '/attachments.php?id=' + row['id'], 'tok-other')
        check("someone else can't delete it", s == 403 and os.path.isfile(stored), (s, b))
        s, b, _ = request('DELETE', API + '/attachments.php?id=' + row['id'], 'tok-poster')
        check('the poster deletes it and the file is removed', s == 200 and not os.path.isfile(stored), (s, b))

        for i in range(4):
            request('POST', API + '/attachments.php', 'tok-poster', fields={'event_id': 'ev1'}, files={'file': (f'f{i}.png', png, 'image/png')})
        s, b, _ = request('POST', API + '/attachments.php', 'tok-poster', fields={'event_id': 'ev1'}, files={'file': ('six.png', png, 'image/png')})
        check('no more than 5 files per event', s == 409, (s, b))

        # ---------- Profile pictures ----------
        s, b, _ = request('POST', API + '/avatars.php', 'tok-other', files={'file': ('me.png', png, 'image/png')})
        url1 = jbody(b).get('url', '')
        check('a user uploads their own photo', s == 201 and '/media/avatars/users/' in url1, (s, b))
        file1 = os.path.join(media, 'avatars', 'users', url1.rsplit('/', 1)[-1])
        size = php(f'$s=getimagesize("{file1.replace(os.sep, "/")}");echo $s[0]."x".$s[1]." ".$s["mime"];').decode()
        check('the photo is re-encoded as a 512x512 JPEG', size == '512x512 image/jpeg', size)
        s, b, _ = request('GET', url1)
        check('the photo is served publicly', s == 200 and b[:2] == b'\xff\xd8', s)
        s, state, _ = request('GET', f'http://127.0.0.1:{MOCK_PORT}/__state', 'tok-super')
        check('the profile now points at the photo', jbody(state)['profiles'][OTHER_ID]['avatar_url'] == url1, '')
        s, b, _ = request('POST', API + '/avatars.php', 'tok-other', files={'file': ('me2.png', png, 'image/png')})
        url2 = jbody(b).get('url', '')
        check('a new photo replaces (deletes) the old file', s == 201 and not os.path.isfile(file1), (s, b))
        s, b, _ = request('POST', API + '/avatars.php', 'tok-other', files={'file': ('x.jpg', fake, 'image/jpeg')})
        check('a non-picture is refused as a photo', s == 415, (s, b))

        s, b, _ = request('POST', API + '/avatars.php?action=preset', 'tok-other', fields={'category': 'anime'}, files={'file': ('p.png', png, 'image/png')})
        check('only the superadmin adds preset pictures', s == 403, (s, b))
        s, b, _ = request('POST', API + '/avatars.php?action=preset', 'tok-super', fields={'category': 'robots'}, files={'file': ('p.png', png, 'image/png')})
        check('preset category must be anime/animal/person', s == 400, (s, b))
        s, b, _ = request('POST', API + '/avatars.php?action=preset', 'tok-super', fields={'category': 'animal'}, files={'file': ('p.png', png, 'image/png')})
        preset = jbody(b)
        preset_file = os.path.join(media, *preset.get('storage_path', 'x').split('/'))
        check('superadmin adds a preset picture', s == 201 and preset.get('category') == 'animal' and os.path.isfile(preset_file), (s, b))
        s, b, _ = request('DELETE', API + '/avatars.php?action=preset&id=' + preset.get('id', ''), 'tok-super')
        check('superadmin deletes a preset and its file', s == 200 and not os.path.isfile(preset_file), (s, b))

        file2 = os.path.join(media, 'avatars', 'users', url2.rsplit('/', 1)[-1])
        s, b, _ = request('POST', API + '/avatars.php?action=remove-user-photo', 'tok-other', fields={'user_id': OTHER_ID})
        check("users can't use the moderation action", s == 403, (s, b))
        s, b, _ = request('POST', API + '/avatars.php?action=remove-user-photo', 'tok-super', fields={'user_id': OTHER_ID})
        s2, state, _ = request('GET', f'http://127.0.0.1:{MOCK_PORT}/__state', 'tok-super')
        check('superadmin removes a user photo (file + profile)', s == 200 and not os.path.isfile(file2) and jbody(state)['profiles'][OTHER_ID]['avatar_url'] is None, (s, b))

        # ---------- Superadmin backup endpoints ----------
        s, b, _ = request('GET', API + '/admin.php?action=usage', 'tok-other')
        check('admin endpoints are superadmin-only', s == 403, (s, b))
        s, b, _ = request('GET', API + '/admin.php?action=usage', 'tok-super')
        usage = jbody(b)
        check('usage reports both storage areas', s == 200 and usage['uploads']['files'] >= 5, (s, b))
        s, b, _ = request('GET', API + '/admin.php?action=list&area=uploads', 'tok-super')
        listed = jbody(b).get('files', [])
        check('list returns stored files', s == 200 and len(listed) >= 5, (s, b))
        first = listed[0]['path']
        s, b, _ = request('GET', API + '/admin.php?action=get&area=uploads&path=' + first, 'tok-super')
        check('get downloads a stored file', s == 200 and len(b) > 0, s)
        s, b, _ = request('POST', API + '/admin.php?action=put&area=uploads&path=restored/r.png', 'tok-super', files={'file': ('r.png', png, 'image/png')})
        check('put restores a file', s == 201 and os.path.isfile(os.path.join(uploads, 'restored', 'r.png')), (s, b))
        s, b, _ = request('GET', API + '/admin.php?action=get&area=uploads&path=../api-config.php', 'tok-super')
        check('path traversal is refused', s == 400, (s, b))
        s, b, _ = request('POST', API + '/admin.php?action=put&area=media&path=avatars/x.php', 'tok-super', files={'file': ('x.php', fake, 'text/plain')})
        check('restore never writes a script', s == 400, (s, b))
    finally:
        server.terminate()
        probe.terminate()
        mock.terminate()
        shutil.rmtree(root, ignore_errors=True)

    print()
    print('ALL PASSED' if not failures else f'{len(failures)} FAILED: {failures}')
    sys.exit(1 if failures else 0)


OTHER_ID = 'aaaaaaaa-0000-4000-8000-000000000002'

if __name__ == '__main__':
    main()
