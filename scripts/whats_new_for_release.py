"""Prints the user-facing "What's new" bullets for one release, taken from
assets/whats_new.md, for the release workflow to put in the GitHub release
(the app shows ONLY these — see lib/whats_new.dart).

    python3 scripts/whats_new_for_release.py v1.17.0+29

Exits with an error (stopping the release before anything is built) when:
  * there's no "## 1.17.0" section, or it has no bullets — every release
    needs notes for users; or
  * a bullet contains an internal term — the notes are public and shown in
    the app, so they must describe what users notice, never how the system
    works behind the scenes. This list is a safety net, not a guarantee.
"""
import re
import sys

NOTES_FILE = 'assets/whats_new.md'

# Words that point at internals: infrastructure, security setup, admin
# tooling, code. Matched as whole words, case-insensitively.
BLOCKED = [
    'supabase', 'hostinger', 'firebase', 'fcm', 'github', 'postgres', 'postgresql',
    'sql', 'rls', 'row-level', 'policy', 'policies', 'trigger', 'rpc', 'cron', 'webhook',
    'edge function', 'service role', 'service_role', 'api', 'endpoint', 'token', 'jwt',
    'secret', 'secrets', 'credential', 'credentials', 'api key', 'vault', 'htaccess',
    'php', 'database', 'server', 'backend', 'migration', 'schema', 'bucket', 'storage path',
    'superadmin', 'portal', 'lgu-admin', 'commit', 'refactor', 'bug id', 'stack trace',
]


def main():
    if len(sys.argv) != 2:
        sys.exit('usage: whats_new_for_release.py <tag, e.g. v1.17.0+29>')
    version = re.sub(r'^v', '', sys.argv[1]).split('+')[0]

    text = open(NOTES_FILE, encoding='utf-8').read()
    text = re.sub(r'<!--.*?-->', '', text, flags=re.S)

    items, current = {}, None
    for raw in text.splitlines():
        line = raw.strip()
        heading = re.match(r'^##\s+v?(\d+\.\d+\.\d+)', line)
        if heading:
            current = heading.group(1)
            items.setdefault(current, [])
        elif current and line.startswith('- ') and line[2:].strip():
            items[current].append(line[2:].strip())

    notes = items.get(version) or []
    if not notes:
        sys.exit(f'No "What\'s new" notes for {version}. Add a "## {version}" section with "- " bullets '
                 f'at the top of {NOTES_FILE} (plain language for users), then tag again.')

    problems = []
    for note in notes:
        for word in BLOCKED:
            if re.search(r'(?<![\w-])' + re.escape(word) + r'(?![\w-])', note, flags=re.I):
                problems.append(f'  "{note}"  ->  mentions "{word}"')
    if problems:
        sys.exit('The "What\'s new" notes for ' + version + ' mention internal details. They are shown to '
                 'every user, so describe what people notice instead:\n' + '\n'.join(problems))

    for note in notes:
        print('- ' + note)


if __name__ == '__main__':
    main()
