#!/bin/sh
# https://github.com/mydumper/mydumper/releases
# yum install libzstd -y 

database="$1"
mail="$2"
name="$3"

SCRIPT_NAME="$(basename ${BASH_SOURCE[0]})"

if [ -z ${database} ]; then
	echo Usage: $0 database mail [backup_name]
	exit
fi

if [ -z ${name} ]; then
	name=`/bin/hostname`
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


backup_dir=/opt/backup/mydumper

if [ ! -e ${backup_dir} ]; then
	mkdir -p ${backup_dir}
fi

myloader  --database ${database} --directory ${backup_dir} --overwrite-tables --innodb-optimize-keys > /tmp/"${SCRIPT_NAME}"_"${database}"_log 2>&1

exitcode="$?"

# output
if [ "${exitcode}" -ne "0" ]; then
    mailx -s "$(echo -e  "Restore MYDUMPER Monthly for ${name} is Error\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/"${SCRIPT_NAME}"_"${database}"_log
else
    mailx -s "$(echo -e  "Restore MYDUMPER Monthly for ${name} is Succesfull\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/"${SCRIPT_NAME}"_"${database}"_log
fi

rm -rf ${backup_dir}/*
exit 0
