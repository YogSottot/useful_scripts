#!/usr/bin/env bash
set -eo pipefail

doc_root="$1"
mail="$2"
name="$4"

HC_UUID="$3"
HC_BASE_URL="https://healthchecks.io/ping"
HC_URL=$HC_BASE_URL/$HC_UUID

# Generate Run IDs
RID=$(uuidgen)

# On start script
curl -fsS -m 30 --retry 5 "${HC_URL}/start?rid=$RID"

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

if [ -z "${doc_root}" ]; then
	echo Usage: "$0" /path/to/document/root mail [backup_name]
	exit
fi

if [ -z "${name}" ]; then
	name=$(/bin/hostname)
fi

settings=${doc_root}/bitrix/.settings.php
dbconn=${doc_root}/bitrix/php_interface/dbconn.php

readcfg() {
        grep -m 1 "$1" "${settings}" | sed "s/.*' => '\(.*\)',.*/\1/"
}

host=$(readcfg host)
username=$(readcfg login)
password=$(readcfg password)
database=$(readcfg database)


utf=$(grep 'BX_UTF' ${dbconn} | grep true)

if [ -z "$utf" ]; then
	charset=cp1251
else
	charset=utf8
fi

find_swift() {
    local swift_bin
    if [[ -x /root/.local/bin/swift ]]; then
        swift_bin="/root/.local/bin/swift"
    elif [[ -x /usr/bin/swift ]]; then
        swift_bin="/usr/bin/swift"
    else
        printf "ERROR: 'swift' binary not found in /root/.local/bin or /usr/bin.\n" >&2
        return 1
    fi
    printf "%s\n" "$swift_bin"
}
if ! swift_path=$(find_swift); then
    exit 1
fi

SCRIPTNAME=$(basename "$0")
LOCKDIR="/var/lock/bitrixdb_${database}"
PIDFILE="${LOCKDIR}/pid"

if ! mkdir "$LOCKDIR" 2>/dev/null
then
    # lock failed, but check for stale one by checking if the PID is really existing
    PID=$(cat "$PIDFILE")
    if ! kill -0 "$PID" 2>/dev/null
    then
       echo "Removing stale lock of nonexistent PID ${PID}" >&2
       rm -rf "$LOCKDIR"
       echo "Restarting myself (${SCRIPTNAME})" >&2
       exec "$0" "$@"
    fi
    echo "$SCRIPTNAME is already running, bailing out" >&2
    exit 1
else
    # lock successfully acquired, save PID
    echo $$ > "$PIDFILE"
fi

trap 'rm -rf ${LOCKDIR}' QUIT INT TERM EXIT
# Do stuff


#backup_dir=${doc_root}/bitrix/backup
backup_dir=/opt/backup/backup_"${name}"

if [ ! -e "${backup_dir}" ]; then
	mkdir -p "${backup_dir}"
fi

function getValueFromINI() {
	local sourceData="$1"; local paramName="$2";
	## 1. Get value "platform=%OUR_VALUE%"
	## 2. Remove illegal characters
	echo "$(echo "$sourceData" | sed -n '/^'"${paramName}"'\ =\(.*\)$/s//\1/p' | tr -d "\r" | tr -d "\n")"
}

function getValueFromINI2() {
        local sourceData="$1"; local paramName="$2";
        ## 1. Get value "platform=%OUR_VALUE%"
        ## 2. Remove illegal characters
        echo "$(echo "$sourceData" | sed -n '/^'"${paramName}"'\ =\(.*\)$/s//\1/p'  | tr -d "\r" | tr -d "\n" | tr -d "/")"
}

sectionContent=$(sed -n '/^\[cloud\]/,/^\[/p' /opt/backup/scripts/config.ini | sed -e '/^\[/d' | sed -e '/^$/d');
project=$(getValueFromINI "$sectionContent" "project");
login=$(getValueFromINI "$sectionContent" "login");
password=$(getValueFromINI "$sectionContent" "password");
url=$(getValueFromINI "$sectionContent" "auth-url");
storage_dir=$(getValueFromINI2 "$sectionContent" "dir");

cd "${doc_root}" && \
timeout -k 15s 3600s nice -n 19 ionice -c2 -n7 \
mysqldump -e --add-drop-table --add-locks \
--skip-lock-tables --single-transaction --quick \
-h"${host}" -uroot --default-character-set=${charset} --ignore-table="${database}".b_xml_tree_import_1c \
"${database}" | pv -L 10m  | \
nice -n 19 ionice -c2 -n7 zstd -c > "${backup_dir}"/"${name}".sql.zst 2>/tmp/"${SCRIPT_NAME}"_"${database}"_log && \
timeout -k 15s 3600s nice -n 19 ionice -c2 -n7 "${swift_path}" -v --os-auth-url "${url}" --os-region-name ru-1 --auth-version 3 --os-project-id "${project}" --os-user-id "${login}" --os-password "${password}" upload -H "X-Delete-After: 604800" --object-name "$(date +%Y-%m-%d-%H:%M)_DB_daily_${name}/" "${storage_dir}" "${backup_dir}"/ >> /tmp/"${SCRIPT_NAME}"_"${database}"_log 2>&1
exitcode="$?"

# On end script with exit code and run ID
curl -fsS -m 30 --retry 5 --data-binary @/tmp/"${SCRIPT_NAME}"_"${database}"_log "${HC_URL}/${exitcode}?rid=$RID"


# output
#timeout -k 15s 3600s your_command

if [ "${exitcode}" -eq 124 ]; then
    mailx -s "$(echo -e  "Backup mysqldump hourly for ${name} is Timeout\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/"${SCRIPT_NAME}"_"${database}"_log
elif [ "${exitcode}" -ne 0 ]; then
    mailx -s "$(echo -e  "Backup mysqldump hourly for ${name} is Error\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/"${SCRIPT_NAME}"_"${database}"_log
else
    echo "Command completed successfully"
fi

rm -rf "${backup_dir:?}"/*
exit 0
