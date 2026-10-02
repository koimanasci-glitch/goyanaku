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
    if zxing:
        shutil.copyfile(zxing, target / 'zxing.min.js')
    elif not (target / 'zxing.min.js').exists():
        raise SystemExit('zxing.min.js belum ada. Jalankan: npm i @zxing/library@0.21.3 lalu berikan path umd/index.min.js')
    (target / '.gitkeep').write_text('', encoding='utf-8')
    return target


if __name__ == '__main__':
    out = build(sys.argv[1] if len(sys.argv) > 1 else '.', sys.argv[2] if len(sys.argv) > 2 else None)
    print('Aset web Flutter siap di', out)
