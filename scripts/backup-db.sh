#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

: "${DB_NAME:?Set DB_NAME}"
: "${DB_USER:?Set DB_USER}"
: "${MYSQL_PWD:?Set MYSQL_PWD (do not put the password in command arguments)}"

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
MYSQLDUMP_BIN="${MYSQLDUMP_BIN:-mysqldump}"

if ! [[ "$DB_PORT" =~ ^[0-9]+$ ]] || ! [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]]; then
  echo "DB_PORT and RETENTION_DAYS must be integers." >&2
  exit 2
fi
if ! command -v "$MYSQLDUMP_BIN" >/dev/null 2>&1; then
  echo "mysqldump was not found: $MYSQLDUMP_BIN" >&2
  exit 127
fi

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
base="$BACKUP_DIR/${DB_NAME}_$stamp.sql.gz"
tmp="$(mktemp "$BACKUP_DIR/.backup.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

"$MYSQLDUMP_BIN" \
  --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" \
  --single-transaction --quick --routines --triggers --events \
  --hex-blob --default-character-set=utf8mb4 --no-tablespaces \
  "$DB_NAME" | gzip -c > "$tmp"

gzip -t "$tmp"
test -s "$tmp"
mv "$tmp" "$base"
sha256sum "$base" > "$base.sha256"
find "$BACKUP_DIR" -maxdepth 1 -type f -name "${DB_NAME}_*.sql.gz" -mtime +"$RETENTION_DAYS" -delete
find "$BACKUP_DIR" -maxdepth 1 -type f -name "${DB_NAME}_*.sql.gz.sha256" -mtime +"$RETENTION_DAYS" -delete
echo "Backup verified: $base"
