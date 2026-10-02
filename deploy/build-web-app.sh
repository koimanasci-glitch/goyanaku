#!/usr/bin/env bash
# Bangun aplikasi GOYANA versi web (HTML yang sama dengan Android) ke backend/public/app/
# sehingga owner bisa membukanya di https://DOMAIN/app/ dan datanya sinkron dengan HP.
# Pakai: bash deploy/build-web-app.sh https://domain-anda.com
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API="${1:-}"
if [[ -z "$API" ]]; then API="$(grep -E '^APP_URL=' "$ROOT/backend/.env" | cut -d= -f2- | tr -d '"')"; fi
[[ "$API" == https://* ]] || { echo "Alamat API harus https:// (contoh: bash $0 https://app.goyana.id)"; exit 1; }
OUT="$ROOT/backend/public/app"
TMP="$(mktemp -d)"
python3 "$ROOT/tools/prepare_web.py" "$ROOT" "$TMP" "--api=$API"
# Pemindai barcode/QR (versi sama dengan APK).
if [[ -f "$ROOT/tests/node_modules/@zxing/library/umd/index.min.js" ]]; then
  cp "$ROOT/tests/node_modules/@zxing/library/umd/index.min.js" "$TMP/zxing.min.js"
else
  curl -fsSL "https://cdn.jsdelivr.net/npm/@zxing/library@0.21.3/umd/index.min.js" -o "$TMP/zxing.min.js"
fi
# Di browser tidak ada plugin HP: capacitor.js kosong membuat aplikasi memakai fitur browser biasa.
echo "/* web: tanpa plugin HP */" > "$TMP/capacitor.js"
rm -rf "$OUT.new" && mv "$TMP" "$OUT.new"
chmod -R a+rX "$OUT.new"
rm -rf "$OUT.old"; [[ -d "$OUT" ]] && mv "$OUT" "$OUT.old"; mv "$OUT.new" "$OUT"; rm -rf "$OUT.old"
echo "Aplikasi web siap: $API/app/"
