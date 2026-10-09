#!/usr/bin/env bash
# Disiapkan setiap container GOYANA mulai. Peran: GOYANA_ROLE=app (web + migrasi) atau scheduler.
set -euo pipefail
cd /srv/goyana/backend

# Folder storage ada di volume; buat subfolder yang dibutuhkan Laravel.
mkdir -p storage/app/public storage/framework/{cache/data,sessions,views} storage/logs bootstrap/cache

# Tunggu database siap (maks. ±2 menit).
for i in $(seq 1 60); do
  php -r 'try{new PDO("mysql:host=".getenv("DB_HOST").";port=".(getenv("DB_PORT")?:3306), getenv("DB_USERNAME"), getenv("DB_PASSWORD"));exit(0);}catch(Throwable $e){exit(1);}' && break
  echo "Menunggu database… ($i)"; sleep 2
done

php artisan config:cache >/dev/null
php artisan route:cache >/dev/null
php artisan view:cache >/dev/null

if [[ "${GOYANA_ROLE:-app}" == "app" ]]; then
  php artisan migrate --force
  php artisan storage:link >/dev/null 2>&1 || true
  # Aplikasi web /app/ dibangun ulang bila versi kode berubah.
  if [[ "${APP_URL:-}" == https://* ]]; then
    stamp="$(cat /srv/goyana/.build-id 2>/dev/null || echo dev)"
    if [[ ! -f public/app/.built || "$(cat public/app/.built)" != "$stamp" ]]; then
      bash /srv/goyana/deploy/build-web-app.sh "$APP_URL" && echo "$stamp" > public/app/.built || echo "Peringatan: aplikasi web /app/ belum terbangun."
    fi
  fi
fi

exec "$@"
