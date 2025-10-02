#!/usr/bin/env bash
set -eo pipefail

# curl https://rclone.org/install.sh | bash

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

SCRIPT_NAME="$(basename ${BASH_SOURCE[0]})"

if [ -z ${doc_root} ]; then
	echo Usage: $0 /path/to/document/root mail [backup_name]
	exit
fi

if [ -z ${name} ]; then
	name=`/bin/hostname`
fi

settings=${doc_root}/bitrix/.settings.php
dbconn=${doc_root}/bitrix/php_interface/dbconn.php

readcfg() {
        grep -m 1 $1 ${settings} | sed "s/.*' => '\(.*\)',.*/\1/"
}

host=`readcfg host`
username=`readcfg login`
password=`readcfg password`
database=`readcfg database`


utf=`grep 'BX_UTF' ${dbconn} | grep true`

if [ -z "$utf" ]; then
	charset=cp1251
else
	charset=utf8
fi

SCRIPTNAME=$(basename $0)
LOCKDIR="/var/lock/bitrixdb_${database}"
PIDFILE="${LOCKDIR}/pid"

if ! mkdir $LOCKDIR 2>/dev/null
then
    # lock failed, but check for stale one by checking if the PID is really existing
    PID=$(cat $PIDFILE)
    if ! kill -0 $PID 2>/dev/null
    then
       echo "Removing stale lock of nonexistent PID ${PID}" >&2
       rm -rf $LOCKDIR
       echo "Restarting myself (${SCRIPTNAME})" >&2
       exec "$0" "$@"
    fi
    echo "$SCRIPTNAME is already running, bailing out" >&2
    exit 1
else
    # lock successfully acquired, save PID
    echo $$ > $PIDFILE
fi

trap "rm -rf ${LOCKDIR}" QUIT INT TERM EXIT

# Do stuff


#backup_dir=${doc_root}/bitrix/backup
backup_dir=/opt/backup/backup_"${name}"

if [ ! -e ${backup_dir} ]; then
	mkdir -p ${backup_dir}
fi

function getValueFromINI() {
	local sourceData=$1; local paramName=$2;
	## 1. Get value "platform=%OUR_VALUE%"
	## 2. Remove illegal characters
	echo $(echo "$sourceData" | sed -n '/^'${paramName}'\ =\(.*\)$/s//\1/p' | tr -d "\r" | tr -d "\n");
}

function getValueFromINI2() {
        local sourceData=$1; local paramName=$2;
        ## 1. Get value "platform=%OUR_VALUE%"
        ## 2. Remove illegal characters
        echo $(echo "$sourceData" | sed -n '/^'${paramName}'\ =\(.*\)$/s//\1/p'  | tr -d "\r" | tr -d "\n" | tr -d "/");
}

sectionContent=$(sed -n '/^\[cloud\]/,/^\[/p' /opt/backup/scripts/config.ini | sed -e '/^\[/d' | sed -e '/^$/d');
login=$(getValueFromINI "$sectionContent" "login");
userkey=$(getValueFromINI "$sectionContent" "password");
storage_dir=$(getValueFromINI2 "$sectionContent" "dir");

cd ${doc_root} && \
nice -n 19 ionice -c2 -n7 \
mysqldump -e --add-drop-table --add-locks \
--disable-keys --extended-insert --order-by-primary --set-charset --create-options --hex-blob --routines --events --triggers \
--skip-lock-tables --single-transaction --quick \
-h${host} -uroot --default-character-set=${charset} --ignore-table=${database}.b_xml_tree_import_1c \
${database} | pv -L 10m  | \
nice -n 19 ionice -c2 -n7 gzip > ${backup_dir}/${name}.sql.gz 2>/tmp/"${SCRIPT_NAME}"_"${database}"_log && \
nice -n 19 ionice -c2 -n7 /usr/local/bin/rclone --verbose --config=/opt/backup/scripts/rclone.conf --checksum copy ${backup_dir} selectel_s3:${storage_dir}/`date +%Y-%m-%d-%H:%M`_DB_daily_"${name}" >> /tmp/"${SCRIPT_NAME}"_"${database}"_log 2>&1

exitcode="$?"

# On end script with exit code and run ID
curl -fsS -m 30 --retry 5 --data-binary @/tmp/"${SCRIPT_NAME}"_"${database}"_log "${HC_URL}/${exitcode}?rid=$RID"

# output
if [ "${exitcode}" -ne "0" ]; then
    mailx -s "$(echo -e  "Backup bitrixdb daily for ${name} is error\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/"${SCRIPT_NAME}"_"${database}"_log
else
    mailx -s "$(echo -e  "Backup bitrixdb daily for ${name} is succesfull\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/"${SCRIPT_NAME}"_"${database}"_log
fi

rm -rf ${backup_dir}/*
exit 0
