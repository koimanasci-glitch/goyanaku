#!/usr/bin/env bash
# Update GOYANA (Docker) setelah ada perubahan di GitHub. Jalankan dari folder repo: bash deploy/docker/update.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
BRANCH="${GOYANA_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
git fetch origin "$BRANCH" && git pull --ff-only origin "$BRANCH"
git rev-parse HEAD > .build-id
bash deploy/docker/backup.sh
docker compose -f deploy/docker/docker-compose.yml up -d --build
docker image prune -f >/dev/null
echo "Update selesai ($(cut -c1-7 .build-id))."
