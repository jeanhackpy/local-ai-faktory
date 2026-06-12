#!/bin/bash
# backups/cron-pgdump.sh
# Backup quotidien de la base Supabase vers MinIO.
# À exécuter via Coolify Scheduled Tasks (POST /scheduled-tasks) ou cron système.
#
# Vars d'env attendues :
#   MINIO_ROOT_USER       — user MinIO
#   MINIO_ROOT_PASSWORD   — password MinIO
#   MINIO_BUCKET          — défaut: "backups"
#   PG_CONTAINER_LABEL    — défaut: "com.docker.compose.service=db"
#
# Cron suggéré : 0 3 * * * (03:00 quotidien)

set -euo pipefail

TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
BACKUP_NAME="supabase-db-${TIMESTAMP}.dump"
TMP_FILE="/tmp/${BACKUP_NAME}"

# 1. Trouver le container postgres
PG_CONTAINER=$(docker ps --filter "label=${PG_CONTAINER_LABEL:-com.docker.compose.service=db}" --format "{{.Names}}" | head -1)
if [ -z "$PG_CONTAINER" ]; then
  echo "ERROR: aucun container postgres trouvé (label=${PG_CONTAINER_LABEL:-com.docker.compose.service=db})" >&2
  exit 1
fi

echo "[$(date -Iseconds)] Backup ${PG_CONTAINER} → ${BACKUP_NAME}"

# 2. pg_dump
docker exec -e PGPASSWORD="${POSTGRES_PASSWORD}" "$PG_CONTAINER" \
  pg_dump -U postgres -d postgres -Fc --no-owner --no-privileges \
  > "$TMP_FILE"

DUMP_SIZE=$(stat -c%s "$TMP_FILE" 2>/dev/null || stat -f%z "$TMP_FILE")
echo "[$(date -Iseconds)] Dump créé : ${DUMP_SIZE} bytes"

# 3. Push vers MinIO
mc alias set backup "http://minio:9000" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" --api S3v4 2>/dev/null || true
mc mb --ignore-existing "backup/${MINIO_BUCKET:-backups}/supabase-db" 2>/dev/null || true
mc cp "$TMP_FILE" "backup/${MINIO_BUCKET:-backups}/supabase-db/${BACKUP_NAME}"

# 4. Cleanup local
rm -f "$TMP_FILE"

# 5. Rétention 30 jours
echo "[$(date -Iseconds)] Nettoyage backups > 30 jours..."
mc find "backup/${MINIO_BUCKET:-backups}/supabase-db/" --older-than 30d --exec "mc rm {}" 2>/dev/null || true

echo "[$(date -Iseconds)] Backup terminé."
