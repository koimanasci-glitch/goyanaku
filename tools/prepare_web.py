"""Copy the app sources and append optional scripts at the real document end."""
from pathlib import Path
from html.parser import HTMLParser
import re
import shutil

PATCHES = [f'goyana-v{v}-{name}.js' for v, name in [
    (181, 'system-fixes'), (182, 'finance-hpp'),
    (183, 'delivery-transport'), (184, 'owner-transport-settings'),
    (185, 'qris-stability'), (187, 'home-navigation'), (188, 'mobile-polish'),
    (189, 'getting-started'), (190, 'subscription-layout'), (191, 'chatbot-settings'), (193, 'qris-map'), (195, 'wa-devices'), (196, 'small-screen'), (197, 'sync'), (198, 'flow-fixes'), (200, 'cash'), (201, 'brand')]]

TEST_PATCH = 'goyana-v192-test-mode.js'
SYNC_CORE = 'goyana-sync-core.js'
SYNC_TAG = f'<script src="{SYNC_CORE}"></script>'

def prepare(source, target, test_mode=False, api_url=None):
    source, target = Path(source), Path(target)
    target.mkdir(parents=True, exist_ok=True)
    branding = source / 'mobile' / 'assets' / 'branding'
    if branding.exists():
        shutil.copytree(branding, target / 'branding', dirs_exist_ok=True)
    text = (source / 'index.html').read_text(encoding='utf-8')
    patches = PATCHES + ([TEST_PATCH] if test_mode else [])
    for name in PATCHES + [TEST_PATCH]:
        text = re.sub(r'<script\s+src=[\"\']' + re.escape(name) + r'[\"\']\s*>\s*</script>', '', text)
    if not test_mode:
        (target / TEST_PATCH).unlink(missing_ok=True)
    for name in patches:
        shutil.copyfile(source / name, target / name)
    # Sync core must run in <head>, before the app reads local storage.
    import os
    api = (api_url if api_url is not None else os.environ.get('GOYANA_API_URL', '')).strip().rstrip('/')
    text = text.replace(SYNC_TAG, '')
    if (source / SYNC_CORE).exists():
        core = (source / SYNC_CORE).read_text(encoding='utf-8').replace('__GOYANA_API_URL__', api.replace("'", ''), 1)
        (target / SYNC_CORE).write_text(core, encoding='utf-8')
        marker = 'id="goyana-reset-storage176"'
        if marker in text:
            at = text.find('</script>', text.find(marker)) + len('</script>')
        elif '<head' in text.lower():
            at = text.find('>', text.lower().find('<head')) + 1
        else:
            at = 0
        text = text[:at] + SYNC_TAG + text[at:]
    before, closing, after = text.rpartition('</body>')
    if not closing:
        raise ValueError('Missing document closing body tag')
    tags = '\n'.join(f'<script src="{name}"></script>' for name in patches)
    text = before + tags + '\n' + closing + after
    class Scripts(HTMLParser):
        def __init__(self):
            super().__init__(); self.sources = []
        def handle_starttag(self, tag, attrs):
            if tag == 'script':
                self.sources.append(dict(attrs).get('src'))
    parser = Scripts(); parser.feed(text)
    assert [s for s in parser.sources if s in patches] == patches, 'Patch scripts must load once, in order'
    (target / 'index.html').write_text(text, encoding='utf-8')
    return text

if __name__ == '__main__':
    import sys
    api = next((a.split('=', 1)[1] for a in sys.argv[3:] if a.startswith('--api=')), None)
    prepare(sys.argv[1] if len(sys.argv) > 1 else '.', sys.argv[2] if len(sys.argv) > 2 else 'app/www', '--test-mode' in sys.argv[3:], api)
