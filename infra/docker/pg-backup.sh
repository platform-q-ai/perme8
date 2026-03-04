#!/bin/sh
# Hourly pg_dump backup with rotation.
# Runs inside the pg_backup container (postgres:16-alpine).
#
# Environment (set in docker-compose):
#   PGHOST, PGUSER, PGPASSWORD, PGDATABASE — libpq connection vars
#   BACKUP_RETAIN — number of most recent dumps to keep (default 24)
set -e

BACKUP_DIR="/backups"
RETAIN="${BACKUP_RETAIN:-24}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
FILENAME="${BACKUP_DIR}/${PGDATABASE}_${TIMESTAMP}.dump"

echo "pg_backup: starting dump -> ${FILENAME}"
pg_dump -Fc -f "${FILENAME}"
echo "pg_backup: dump complete ($(du -h "${FILENAME}" | cut -f1))"

# Rotate: keep only the N most recent dumps
TOTAL=$(ls -1t "${BACKUP_DIR}"/*.dump 2>/dev/null | wc -l)
if [ "${TOTAL}" -gt "${RETAIN}" ]; then
  REMOVE=$((TOTAL - RETAIN))
  ls -1t "${BACKUP_DIR}"/*.dump | tail -n "${REMOVE}" | while read -r OLD; do
    echo "pg_backup: pruning ${OLD}"
    rm -f "${OLD}"
  done
fi

echo "pg_backup: done. $(ls -1 "${BACKUP_DIR}"/*.dump 2>/dev/null | wc -l) backups retained."
