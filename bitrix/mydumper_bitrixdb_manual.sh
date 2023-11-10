#!/usr/bin/env bash
set -eo pipefail
# https://github.com/mydumper/mydumper/releases
# yum install libzstd -y 

doc_root="$1"

cpu=`nproc --ignore=1`

SCRIPT_NAME="$(basename ${BASH_SOURCE[0]})"

if [ -z ${doc_root} ]; then
	echo Usage: $0 /path/to/document/root
	exit 1
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
backup_dir=/opt/backup/mydumper

if [ ! -e ${backup_dir} ]; then
	mkdir -p ${backup_dir}
fi

printf "Start first dump db: ${database}\n"
mydumper --defaults-file /root/.my.cnf --threads "${cpu}" --compress --less-locking --use-savepoints  --regex "^(?=(?:(${database}\.)))(?!(?:(${database}\.b_stat|${database}\.b_search|${database}\.b_event_log$|${database}\.b_composite)))" --outputdir "${backup_dir}" 

printf "Start second dump db: ${database}\n"
mydumper --defaults-file /root/.my.cnf --threads "${cpu}" --compress --less-locking --use-savepoints --no-data --regex "^(${database}\.b_stat|${database}\.b_search|${database}\.b_event_log$|${database}\.b_composite)" --outputdir "${backup_dir}" 

mydumper --version > "${backup_dir}"/mydumper_version
