"""Build the web assets bundled inside the Flutter Android app.

Usage: python tools/prepare_flutter_web.py [repo_root] [zxing.min.js]

The output in mobile/assets/web is generated (git-ignored). It is the same
index.html + goyana-v*.js bundle the Capacitor APK uses, with capacitor.js
replaced by the Flutter bridge in mobile/web_bridge/capacitor.js.
"""
from pathlib import Path
import shutil
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from prepare_web import prepare  # noqa: E402


def build(root='.', zxing=None):
    root = Path(root).resolve()
    target = root / 'mobile' / 'assets' / 'web'
    if target.exists():
        shutil.rmtree(target)
    prepare(root, target)
    shutil.copyfile(root / 'mobile' / 'web_bridge' / 'capacitor.js', target / 'capacitor.js')
    # SQLite storage shim must be the very first script so every app read uses it.
    shutil.copyfile(root / 'mobile' / 'web_bridge' / 'goyana-store.js', target / 'goyana-store.js')
    index = target / 'index.html'
    html = index.read_text(encoding='utf-8')
    tag = '<script src="goyana-store.js"></script>'
    if tag not in html:
        at = html.find('>', html.lower().find('<head')) + 1
        html = html[:at] + tag + html[at:]
        index.write_text(html, encoding='utf-8')
    if zxing:
        shutil.copyfile(zxing, target / 'zxing.min.js')
    elif not (target / 'zxing.min.js').exists():
        raise SystemExit('zxing.min.js belum ada. Jalankan: npm i @zxing/library@0.21.3 lalu berikan path umd/index.min.js')
    (target / '.gitkeep').write_text('', encoding='utf-8')
    return target


if __name__ == '__main__':
    out = build(sys.argv[1] if len(sys.argv) > 1 else '.', sys.argv[2] if len(sys.argv) > 2 else None)
    print('Aset web Flutter siap di', out)
