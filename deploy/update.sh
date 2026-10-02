#!/usr/bin/env bash
# Update GOYANA di server setelah ada perubahan di GitHub. Jalankan dari folder repo: bash deploy/update.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
BRANCH="${GOYANA_BRANCH:-main}"
git fetch origin "$BRANCH" && git checkout -q "$BRANCH" && git pull --ff-only origin "$BRANCH"
cd backend
php artisan down --retry=15 || true
trap 'php artisan up' EXIT
composer install --no-dev --prefer-dist --optimize-autoloader --no-interaction
php artisan migrate --force
php artisan config:cache && php artisan route:cache && php artisan view:cache
cd "$ROOT" && bash deploy/build-web-app.sh
echo "Selesai. Cek https://DOMAIN/admin/system"
