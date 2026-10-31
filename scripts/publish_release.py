"""Puts one release file on the download page (calendar.bongabong.gov.ph/download/),
which is where the app checks for updates. Run by the release workflow:

    python3 scripts/publish_release.py android build/app/outputs/flutter-apk/e-calendar-1.18.0.apk
    python  scripts/publish_release.py windows installer_output/e-calendar-1.18.0-setup.exe

Needs, from the environment:
  RELEASE_UPLOAD_SECRET  the same value as private/release-upload-secret.txt
                         on the server (see hostinger/README.md)
  GITHUB_REF_NAME        the release tag, e.g. v1.18.0+30 (set by GitHub Actions)
  RELEASE_UPLOAD_URL     optional; defaults to the live site's api/releases.php

Uploads the file in pieces (the server takes at most 8 MB per request),
resuming where the server says it stopped, then publishes it with its size,
SHA-256, and every version's "What's new" notes from assets/whats_new.md.
Exits non-zero on any failure, which fails the release.
"""
import datetime
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request

from whats_new_for_release import all_notes, checked_notes, version_of

DEFAULT_URL = 'https://calendar.bongabong.gov.ph/api/releases.php'
CHUNK = 8 * 1024 * 1024
ATTEMPTS = 5
MANILA = datetime.timezone(datetime.timedelta(hours=8))


def call(url, secret, data, content_type='application/octet-stream'):
    """(status, parsed JSON body) — retries network errors and server errors."""
    for attempt in range(1, ATTEMPTS + 1):
        req = urllib.request.Request(url, data=data, method='POST', headers={
            'X-Release-Secret': secret,
            'Content-Type': content_type,
            'User-Agent': 'ecalendar-release/1',
        })
        try:
            with urllib.request.urlopen(req, timeout=120) as res:
                return res.status, json.loads(res.read() or b'{}')
        except urllib.error.HTTPError as e:
            body = e.read()
            try:
                parsed = json.loads(body)
            except ValueError:
                parsed = {'error': body[:300].decode('utf-8', 'replace')}
            if e.code < 500 or attempt == ATTEMPTS:
                return e.code, parsed
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            if attempt == ATTEMPTS:
                sys.exit(f'Could not reach {url}: {e}')
        time.sleep(3 * attempt)
    raise AssertionError('unreachable')


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ('android', 'windows'):
        sys.exit('usage: publish_release.py <android|windows> <file>')
    platform, path = sys.argv[1], sys.argv[2]
    secret = os.environ.get('RELEASE_UPLOAD_SECRET', '').strip()
    if len(secret) < 32:
        sys.exit('RELEASE_UPLOAD_SECRET is missing (or shorter than 32 characters). Add it in the '
                 'repository settings: Settings > Secrets and variables > Actions. See hostinger/README.md.')
    tag = os.environ.get('GITHUB_REF_NAME', '')
    version = version_of(tag)
    build = int(tag.split('+')[1]) if '+' in tag else 0
    url = os.environ.get('RELEASE_UPLOAD_URL', DEFAULT_URL)

    name = os.path.basename(path)
    expected = f'e-calendar-{version}' + ('.apk' if platform == 'android' else '-setup.exe')
    if name != expected:
        sys.exit(f'Expected the file to be named {expected}, got {name}.')

    checked_notes(version)  # stops here if this version has no notes for users
    changelog = all_notes()

    size = os.path.getsize(path)
    digest = hashlib.sha256()
    offset = 0
    resumes = 0
    with open(path, 'rb') as f:
        while offset < size:
            f.seek(offset)
            piece = f.read(CHUNK)
            status, body = call(f'{url}?action=chunk&name={name}&offset={offset}&total={size}', secret, piece)
            if status == 409 and isinstance(body.get('received'), int) and resumes < 10:
                resumes += 1
                offset = body['received']  # resume where the server stopped
                continue
            if status != 200:
                sys.exit(f'Upload failed at byte {offset} ({status}): {body.get("error", body)}')
            offset = body['received']
            print(f'  {name}: {offset * 100 // size}%')
        f.seek(0)
        for block in iter(lambda: f.read(1024 * 1024), b''):
            digest.update(block)

    status, body = call(f'{url}?action=publish', secret, json.dumps({
        'version': version,
        'build': build,
        'date': datetime.datetime.now(MANILA).date().isoformat(),
        'platform': platform,
        'file': name,
        'size': size,
        'sha256': digest.hexdigest(),
        'changelog': changelog,
    }).encode(), 'application/json')
    if status != 200:
        sys.exit(f'Publishing failed ({status}): {body.get("error", body)}')
    print(f'Published {name} ({size} bytes) as version {version}+{build} for {platform}: {body["latest"]["url"]}')


if __name__ == '__main__':
    main()
