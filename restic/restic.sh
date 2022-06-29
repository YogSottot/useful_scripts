#!/usr/bin/env bash
set -eo pipefail

target=$1
mail=$2
hostname=`/bin/hostname`

cd /home/bitrix

SCRIPTNAME=$(basename $0)
LOCKDIR="/var/lock/${SCRIPTNAME}"
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
output=`/usr/local/bin/restic --exclude-file=/opt/backup/exclude_restic.txt --no-cache backup ${target} > /tmp/restic_log 2>&1`
exitcode=$?

# output
if [ "${exitcode}" = "0" ]; then
    mailx -s "$(echo -e  "Restic backup on ${hostname} is succesfull\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/restic_log
fi

if [ "${exitcode}" = "1" ]; then
    mailx -s "$(echo -e  "Restic backup on ${hostname} is error\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/restic_log
fi

if [ "${exitcode}" = "2" ]; then
    mailx -s "$(echo -e  "Restic backup on ${hostname} is error\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/restic_log
fi




# check consistency
# restic check --read-data

# get list of backups
# restic snapshots

# this will restore to /home/bitrix/www without upload
# restic restore latest --target /home/bitrix/ --exclude www/upload

# restore only one file or dir
# restic restore da519e28 --target /home/bitrix/ --include www/bitrix/some_file.php

# full restore into /home/bitrix/www if backup target was www
# restic restore da519e28 --target /home/bitrix


# search some file in all snapshots
# restic find foo

# mysql?
# mysqldump $MYSQLDUMP_ARGS $db | gzip --rsyncable  | restic backup --stdin --stdin-filename hostname.sql.gz
# MYSQLDUMP_ARGS="--skip-dump-date --single-transaction --complete-insert --add-drop-table --quick --quote-names --triggers --routines --events"

# grafana?
# https://forum.restic.net/t/restic-grafana-dashboard/1662

# restic mount repo
# restic mount --allow-other /home/bitrix/www-mount/
# ln -s /home/bitrix/www-mount/snapshots/latest/www /home/bitrix/www

/usr/local/bin/restic forget --prune --keep-daily 15 --keep-weekly 4 --keep-monthly 4  > /dev/null 2>&1



restic cache --cleanup

exit 0


# useful links
# https://github.com/fukawi2/resticctl
# https://github.com/alphapapa/restic-runner
# https://github.com/erikw/restic-systemd-automatic-backup
# 
