#!/usr/bin/env bash
set -eo pipefail

# curl https://rclone.org/install.sh | bash

doc_root="$1"
mail="$2"
name="$3"

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


utf=$(grep 'BX_UTF' "${dbconn}" | grep true)

if [ -z "$utf" ]; then
	charset=cp1251
else
	charset=utf8
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
login=$(getValueFromINI "$sectionContent" "login");
userkey=$(getValueFromINI "$sectionContent" "password");
storage_dir=$(getValueFromINI2 "$sectionContent" "dir");


# Variables
remote_name="your_remote_name"         # rclone remote name (configured in rclone)
remote_dir="/remote/directory"         # Remote directory path
timestamp=$(date +%Y-%m-%d-%H:%M)      # Timestamp for directory



#cd ${doc_root} && \
#nice -n 19 ionice -c2 -n7 \
#mysqldump -e --add-drop-table --add-locks \
#--skip-lock-tables --single-transaction --quick \
#-h${host} -uroot --default-character-set=${charset} --ignore-table=${database}.b_xml_tree_import_1c \
#${database} | pv -L 10m  | \
#nice -n 19 ionice -c2 -n7 gzip > ${backup_dir}/${name}.sql.gz 2>/tmp/"${SCRIPT_NAME}"_"${database}"_log && \

/bin/tar cfp - --exclude '*.tar.gz' --exclude '*.log' --exclude 'debug_params.txt' --exclude 'webstat.' --exclude 'bitrix/tmp/*' --exclude 'bitrix/updates/*' --exclude 'bitrix/backup/*' --exclude 'bitrix/*cache/*' --exclude 'bitrix/html_pages/*' --exclude 'upload/resize_cache/*' --exclude 'upload/tmp/*' --exclude 'upload/1c_catalog/*' --exclude 'upload/1c_catalog_history/*' -C /home/bitrix/ www/ | zstd -c > "${backup_dir}"/"${name}"_"${timestamp}".tar.zst && \

# Create the directory on the remote with the current timestamp
rclone --config=/opt/backup/scripts/rclone.conf mkdir "${remote_name}:${remote_dir}/${timestamp}" > /tmp/"${SCRIPT_NAME}"_"${database}"_log 2>&1 && \

# Upload the backup directory to the newly created directory on the remote
rclone --config=/opt/backup/scripts/rclone.conf copy "${backup_dir}" "${remote_name}:${remote_dir}/${timestamp}" >> /tmp/"${SCRIPT_NAME}"_"${database}"_log 2>&1 && \

# Delete files older than 14 days on the remote
rclone --config=/opt/backup/scripts/rclone.conf delete "${remote_name}:${remote_dir}" --min-age 14d >> /tmp/"${SCRIPT_NAME}"_"${database}"_log 2>&1 && \


exitcode="$?"

# output
if [ "${exitcode}" -ne "0" ]; then
    mailx -s "$(echo -e  "Backup rclone ftp daily for ${name} is error\nContent-Type: text/plain; charset=UTF-8")" "${mail}" < /tmp/"${SCRIPT_NAME}"_"${database}"_log
else
    mailx -s "$(echo -e  "Backup rclone ftp daily for ${name} is succesfull\nContent-Type: text/plain; charset=UTF-8")" "${mail}" < /tmp/"${SCRIPT_NAME}"_"${database}"_log
fi

rm -rf "${backup_dir:?}"/*
exit 0

# unpack
# tar --use-compress-program=unzstd -xvf archive.tar.zst
# zstd -d archive.sql.zst