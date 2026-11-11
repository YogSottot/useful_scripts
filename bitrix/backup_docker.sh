#!/usr/bin/env bash
set -Eeuo pipefail

# ----------------------------
# CONFIG
# ----------------------------
source /var/www/user/domain.tld/.env
CONTAINER="f-${NAME_DOCKER_COMPOSER_SERVICE}"
DATA_DIR="/usr/src/app/data"

source /opt/backup/restic/rc.files/www.rc
export RESTIC_REPOSITORY="${RESTIC_REPOSITORY}"
export RESTIC_PASSWORD="${RESTIC_PASSWORD}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"

DATE=$(date +%F_%H-%M-%S)
HOST=$(hostname)

LOG_FILE="/tmp/backup_${DATE}.log"
EXITCODE=0

# ----------------------------
# HEALTHCHECK
# ----------------------------
HC_UUID=
HC_BASE_URL="https://healthchecks.io/ping"
HC_URL="$HC_BASE_URL/$HC_UUID"
RID=$(/usr/bin/uuidgen)

hc() { curl -fsS --max-time 30 --retry 5 "$@" >/dev/null 2>&1 || :; }
hc_start() { hc "${HC_URL}/start?rid=${RID}"; }
hc_end() { local code=$1; hc --data-binary @"$LOG_FILE" "${HC_URL}/${code}?rid=${RID}"; }

# ----------------------------
# START
# ----------------------------
hc_start

{
  echo "[*] Backup started: $DATE"

  if ! docker exec "$CONTAINER" sqlite3 --version >/dev/null 2>&1; then
  echo "sqlite3 missing in container"
  exit 1
  fi
  
  docker exec "$CONTAINER" sh -c "
    set -e
    sqlite3 ${DATA_DIR}/app.db '.backup /tmp/app.db'
    tar -cz \
      -C ${DATA_DIR} files \
      -C /tmp app.db
  " | restic backup \
        --stdin \
        --stdin-filename "sqlite-backup-${HOST}-${DATE}.tar.gz" \
        --tag docker \
        --tag sqlite

  echo "[*] Running retention policy"

  restic forget \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 4 \
    --prune

  echo "[+] Backup completed"

} >"$LOG_FILE" 2>&1 || EXITCODE=$?

# ----------------------------
# END
# ----------------------------
hc_end "$EXITCODE"

exit "$EXITCODE"
