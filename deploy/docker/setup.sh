#!/usr/bin/env bash
# Pasang GOYANA di VPS baru (Ubuntu 22/24) dengan Docker. Jalankan dari folder repo:
#   bash deploy/docker/setup.sh app.goyana.id
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
DOMAIN="${1:-}"
[[ -n "$DOMAIN" ]] || { echo "Pakai: bash deploy/docker/setup.sh DOMAIN   (contoh: app.goyana.id)"; exit 1; }

if ! command -v docker >/dev/null; then
  echo "Memasang Docker…"; curl -fsSL https://get.docker.com | sh
fi

ENV=deploy/docker/.env
if [[ ! -f "$ENV" ]]; then
  cp deploy/docker/env.example "$ENV"
  rand() { openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 32; }
  sed -i "s|^DOMAIN=.*|DOMAIN=$DOMAIN|; s|^APP_URL=.*|APP_URL=https://$DOMAIN|" "$ENV"
  sed -i "s|^APP_KEY=.*|APP_KEY=base64:$(openssl rand -base64 32)|" "$ENV"
  sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=$(rand)|; s|^DB_ROOT_PASSWORD=.*|DB_ROOT_PASSWORD=$(rand)|" "$ENV"
  sed -i "s|^MAIL_FROM_ADDRESS=.*|MAIL_FROM_ADDRESS=noreply@$DOMAIN|" "$ENV"
  chmod 600 "$ENV"
  echo "Dibuat $ENV (password acak). Simpan cadangannya di tempat aman."
fi

git rev-parse HEAD > .build-id 2>/dev/null || date +%s > .build-id
docker compose -f deploy/docker/docker-compose.yml up -d --build
echo "Menunggu server siap…"; sleep 15
docker compose -f deploy/docker/docker-compose.yml exec app php artisan goyana:admin || true

cat <<MSG

Selesai. Langkah berikut:
  1. Pastikan DNS domain $DOMAIN mengarah ke IP VPS ini (A record). HTTPS dibuat otomatis.
  2. Buka https://$DOMAIN/admin/system — semua harus hijau.
  3. Kabari Claude: alamat https://$DOMAIN ditanam ke APK supaya HP login & sinkron.
  4. Backup harian: (crontab -l 2>/dev/null; echo "30 2 * * * cd $ROOT && bash deploy/docker/backup.sh") | crontab -
MSG
