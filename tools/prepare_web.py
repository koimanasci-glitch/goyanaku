"""Copy the app sources and append optional scripts at the real document end."""
from pathlib import Path
from html.parser import HTMLParser
import re
import shutil

PATCHES = [f'goyana-v{v}-{name}.js' for v, name in [
    (181, 'system-fixes'), (182, 'finance-hpp'),
    (183, 'delivery-transport'), (184, 'owner-transport-settings'),
    (185, 'qris-stability'), (187, 'home-navigation'), (188, 'mobile-polish'),
    (189, 'getting-started'), (190, 'subscription-layout'), (191, 'chatbot-settings'), (193, 'qris-map'), (195, 'wa-devices'), (196, 'small-screen')]]

TEST_PATCH = 'goyana-v192-test-mode.js'

def prepare(source, target, test_mode=False):
    source, target = Path(source), Path(target)
    target.mkdir(parents=True, exist_ok=True)
    text = (source / 'index.html').read_text(encoding='utf-8')
    patches = PATCHES + ([TEST_PATCH] if test_mode else [])
    for name in PATCHES + [TEST_PATCH]:
        text = re.sub(r'<script\s+src=[\"\']' + re.escape(name) + r'[\"\']\s*>\s*</script>', '', text)
    if not test_mode:
        (target / TEST_PATCH).unlink(missing_ok=True)
    for name in patches:
        shutil.copyfile(source / name, target / name)
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
    prepare(sys.argv[1] if len(sys.argv) > 1 else '.', sys.argv[2] if len(sys.argv) > 2 else 'app/www', '--test-mode' in sys.argv[3:])
