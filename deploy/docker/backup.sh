#!/usr/bin/env bash
# Cadangan database GOYANA ke folder ~/goyana-backup (14 hari terakhir disimpan).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
DIR="${GOYANA_BACKUP_DIR:-$HOME/goyana-backup}"; mkdir -p "$DIR"
set -a; . deploy/docker/.env; set +a
FILE="$DIR/goyana-$(date +%F-%H%M).sql.gz"
docker compose -f deploy/docker/docker-compose.yml exec -T db \
  mysqldump -uroot -p"$DB_ROOT_PASSWORD" --single-transaction --routines "$DB_DATABASE" | gzip > "$FILE"
find "$DIR" -name 'goyana-*.sql.gz' -mtime +14 -delete
echo "Backup: $FILE"
