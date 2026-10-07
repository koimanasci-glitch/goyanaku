"""Buat mobile/lib/pure/page_templates.dart dari tangkapan HTML (mobile/test/fixtures/pure/pages/*.json).

Tiap berkas = model halaman formulir persis seperti yang dikirim HTML ke Mode Hibrida
({"title":..., "items":[...]}), direkam dari bundel web final lewat capacitor.js.
Pakai: python tools/gen_pure_templates.py
"""
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent / 'mobile'
out = ["// DIBUAT OTOMATIS oleh tools/gen_pure_templates.py dari tangkapan HTML. Jangan diedit manual.", '', 'const pageTemplates = <String, String>{']
for f in sorted((root / 'test/fixtures/pure/pages').glob('*.json')):
    text = json.dumps(json.loads(f.read_text(encoding='utf-8')), ensure_ascii=False, separators=(',', ':'))
    assert "'''" not in text
    out.append(f"  '{f.stem}': r'''{text}''',")
out.append('};')
guides = json.loads((root / 'test/fixtures/pure/guides.json').read_text(encoding='utf-8'))
out += ['', '/// Popup panduan Pusat Bantuan (guide135): pohon tampilan dari HTML + halaman tujuan "Coba Sekarang".', "const guideSheets = r'''" + json.dumps([{'mirror': g['mirror'], 'go': g['go']} for g in guides], ensure_ascii=False, separators=(',', ':')) + "''';"]
cc = json.loads((root / 'test/fixtures/cashclose.json').read_text(encoding='utf-8'))
out += ['', '/// Susunan halaman Tutup Kasir (cashclose) dari HTML; angka diisi oleh logika A7.', "const cashCloseTemplate = r'''" + json.dumps(cc, ensure_ascii=False, separators=(',', ':')) + "''';"]
(root / 'lib/pure/page_templates.dart').write_text('\n'.join(out) + '\n', encoding='utf-8')
print('ok', len(out) - 4)
