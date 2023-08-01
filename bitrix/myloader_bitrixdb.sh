#!/usr/bin/env bash
set -eo pipefail
# https://github.com/mydumper/mydumper/releases
# yum install libzstd -y 

doc_root="$1"
backup_dir="$2"



cpu=`nproc --ignore=1`

SCRIPT_NAME="$(basename ${BASH_SOURCE[0]})"

if [ -z ${doc_root} ]; then
	echo Usage: $0 /path/to/document/root /path/to/backup/dir
	exit 1
fi

if [ -z ${backup_dir} ]; then
	echo Usage: $0 /path/to/document/root /path/to/backup/dir
	exit 1
fi

if [ -z ${name} ]; then
	name=`/bin/hostname`
fi

dbconn=${doc_root}/bitrix/php_interface/dbconn.php

readcfg() {
	grep $1 ${dbconn} | sed 's/.*"\(.*\)".*/\1/'
}

host=`readcfg DBHost`
username=`readcfg DBLogin`
password=`readcfg DBPassword`
database=`readcfg DBName`

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



printf "Start load dump db: ${database}\n"
myloader --defaults-file /root/.my.cnf --threads "${cpu}" --database ${database} --directory ${backup_dir} --overwrite-tables
