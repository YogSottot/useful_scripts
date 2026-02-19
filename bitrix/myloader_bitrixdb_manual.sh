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

readcfg() {
        grep -m 1 $1 ${settings} | sed "s/.*' => '\(.*\)',.*/\1/"
}

host=`readcfg host`
username=`readcfg login`
password=`readcfg password`
database=`readcfg database`


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

backup_dir=/opt/backup/mydumper

if [ ! -e ${backup_dir} ]; then
	mkdir -p ${backup_dir}
fi

printf "Start load dump db: ${database}\n"
myloader --defaults-extra-file /root/.my.cnf --threads "${cpu}" --database ${database} --directory ${backup_dir} --optimize-keys --drop-table
