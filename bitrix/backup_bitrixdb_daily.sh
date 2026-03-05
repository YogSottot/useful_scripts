#!/usr/bin/env bash
set -euo pipefail

# ----------------------------
# CONFIG / ARGUMENTS
# ----------------------------
DOC_ROOT="${1:-}"
HC_UUID="${2:-}"
MAIL="${3:-}"
NAME="${4:-$(hostname)}"

HC_BASE_URL="https://healthchecks.io/ping"
HC_URL="$HC_BASE_URL/$HC_UUID"
RID=$(/usr/bin/uuidgen)

SCRIPT_NAME="$(basename "$0")"

# ----------------------------
# FUNCTIONS
# ----------------------------
hc() { curl -fsS --max-time 30 --retry 5 "$@" >/dev/null 2>&1 || :; }
hc_start() { hc "${HC_URL}/start?rid=${RID}"; }
hc_end() { local code=$1; hc --data-binary @"$LOG_FILE" "${HC_URL}/${code}?rid=${RID}"; }

readcfg() { local key=$1 file=$2; grep -m1 "$key" "$file" | sed "s/.*' => '\(.*\)',.*/\1/"; }

find_swift() {
    for p in "/root/.local/bin/swift" "/usr/bin/swift"; do
        [[ -x "$p" ]] && { echo "$p"; return 0; }
    done
    echo "ERROR: swift binary not found" >&2
    return 1
}

get_ini_value() { local section="$1" key="$2"; sed -n "/^\[${section}\]/,/^\[/{/^\[/d;/^$/d;s/^${key}\s*=\s*//p}" /opt/backup/scripts/config.ini | tr -d "\r\n/"; }

# ----------------------------
# READ BITRIX CONFIG
# ----------------------------
SETTINGS="${DOC_ROOT}/bitrix/.settings.php"

DB_HOST=$(readcfg host "$SETTINGS")
#DB_USER=$(readcfg login "$SETTINGS")
DB_USER=root
DB_PASS=$(readcfg password "$SETTINGS")
DB_NAME=$(readcfg database "$SETTINGS")
DB_CHARSET=$(get_utf_charset "$DBCONN")

SWIFT_BIN=$(find_swift)

# ----------------------------
# CLOUD CONFIG
# ----------------------------
SECTION="cloud"
PROJECT=$(get_ini_value "$SECTION" "project")
LOGIN=$(get_ini_value "$SECTION" "login")
PASSWORD=$(get_ini_value "$SECTION" "password")
URL=$(get_ini_value "$SECTION" "auth-url")
STORAGE_DIR=$(get_ini_value "$SECTION" "dir")

# ----------------------------
# PER-DATABASE LOCK & LOG
# ----------------------------
LOCK_DIR="/var/lock/bitrixdb_${DB_NAME}"
LOG_FILE="/tmp/${SCRIPT_NAME}_${DB_NAME}.log"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    PID=$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")
    if [[ -z "$PID" ]] || ! kill -0 "$PID" 2>/dev/null; then
        echo "Removing stale lock for DB $DB_NAME (PID $PID)" >&2
        rm -rf "$LOCK_DIR"
        exec "$0" "$@"  # restart
    fi
    echo "$SCRIPTNAME for DB $DB_NAME already running, exiting" >&2
    exit 1
else
    echo $$ > "$LOCK_DIR/pid"
fi

trap 'rm -rf "$LOCK_DIR"' QUIT INT TERM EXIT

# ----------------------------
# CREATE BACKUP DIR
# ----------------------------
BACKUP_DIR="/opt/backup/backup_${NAME}"
mkdir -p "$BACKUP_DIR"
: > "$LOG_FILE"

# ----------------------------
# HEALTHCHECK START
# ----------------------------
hc_start

# ----------------------------
# BACKUP / UPLOAD
# ----------------------------
#START_TS=$(date +%s)

{
    echo "Backup started: $(date -Is)"
    cd "$DOC_ROOT"

    timeout -k 15s 3600s nice -n 19 ionice -c2 -n7 \
    mysqldump -e --add-drop-table --add-locks \
        --skip-lock-tables --single-transaction --quick \
        -h"$DB_HOST" -u"$DB_USER" --password="$DB_PASS" \
        --default-character-set="$DB_CHARSET" \
        --ignore-table="${DB_NAME}.b_xml_tree_import_1c" \
        --ignore-table="${DB_NAME}.b_sec_wwall_rules" \
        --ignore-table="${DB_NAME}.b_sec_iprule" \
        --ignore-table="${DB_NAME}.b_sec_session" \
        "$DB_NAME" | pv -L 10m | \
    nice -n 19 ionice -c2 -n7 zstd -c > "$BACKUP_DIR/${NAME}.sql.zst"

    timeout -k 15s 3600s nice -n 19 ionice -c2 -n7 \
    "$SWIFT_BIN" -v --os-auth-url "$URL" --auth-version 3 \
        --os-region-name ru-1 --os-project-id "$PROJECT" \
        --os-user-id "$LOGIN" --os-password "$PASSWORD" \
        upload -H "X-Delete-After: 1209600" \
        --object-name "$(date +%Y-%m-%d-%H:%M)_DB_daily_${NAME}/" \
        "$STORAGE_DIR" "$BACKUP_DIR/"

} >"$LOG_FILE" 2>&1 || true

EXITCODE=$?

# ----------------------------
# HEALTHCHECK END
# ----------------------------
hc_end "$EXITCODE"

# ----------------------------
# EMAIL REPORT
# ----------------------------
SUBJECT="Backup mysqldump daily for ${NAME}"

if [[ "$EXITCODE" -eq 124 ]]; then
    SUBJECT+=" is Timeout"
elif [[ "$EXITCODE" -ne 0 ]]; then
    SUBJECT+=" is Error"
else
    SUBJECT+=" is Successful"
fi

mailx -s "$(echo -e "$SUBJECT\nContent-Type: text/plain; charset=UTF-8")" "$MAIL" < "$LOG_FILE"

# ----------------------------
# CLEANUP
# ----------------------------
rm -rf "${BACKUP_DIR:?}"/*

exit "$EXITCODE"
