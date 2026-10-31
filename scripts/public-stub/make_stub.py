"""Builds the small PUBLIC repository that keeps the old GitHub addresses
working after the code repository goes private (see GITHUB.md, "Private code
repository"). It contains no code: a README and GitHub Pages redirects.

    python scripts/public-stub/make_stub.py <empty output folder>

Old address (GitHub Pages)                         -> new address
https://vincentjhon31.github.io/barangay-events/            download page
https://vincentjhon31.github.io/barangay-events/lgu-admin/  admin portal
https://vincentjhon31.github.io/barangay-events/store/      download page

Installed apps from 1.17 and older still check that repository's latest
GitHub release for updates, so the stub also gets ONE release: the first
version that checks the download page instead (1.18.0), with its APK and
Windows installer attached. Once they update, they never ask GitHub again.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SITE = 'https://calendar.bongabong.gov.ph'
REDIRECTS = {
    'docs/index.html': (SITE + '/download/', 'the download page'),
    'docs/lgu-admin/index.html': (SITE + '/lgu-admin/', 'the admin portal'),
    'docs/store/index.html': (SITE + '/download/', 'the download page'),
}
README = f"""# eBongabong Calendar

The events calendar app of the Municipality of Bongabong, Oriental Mindoro.

**Download it here: {SITE}/download/** (Android and Windows)

You can also use it in your browser at {SITE}/.

This repository only keeps old links working. The app's source code is not public.
"""


def redirect_page(target, label):
    with open(os.path.join(HERE, 'redirect-page.html'), encoding='utf-8') as f:
        return f.read().replace('__TARGET__', target).replace('__LABEL__', label)


def main():
    if len(sys.argv) != 2:
        sys.exit('usage: make_stub.py <empty output folder>')
    out = sys.argv[1]
    if os.path.exists(out) and os.listdir(out):
        sys.exit(f'{out} is not empty.')
    for path, (target, label) in REDIRECTS.items():
        full = os.path.join(out, *path.split('/'))
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, 'w', encoding='utf-8', newline='\n') as f:
            f.write(redirect_page(target, label))
    # Plain files, no Jekyll processing.
    open(os.path.join(out, 'docs', '.nojekyll'), 'w').close()
    with open(os.path.join(out, 'README.md'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(README)
    print('Wrote', ', '.join(['README.md', 'docs/.nojekyll'] + list(REDIRECTS)), 'to', out)


if __name__ == '__main__':
    main()
