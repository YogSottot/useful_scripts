#!/usr/bin/env bash

SCRIPTNAME=$(basename $0)
LOCKDIR="/home/bitrix/www/bitrix/cron/lock/${SCRIPTNAME}"
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

/usr/bin/php -f /home/bitrix/www/bitrix/php_interface/crontab/seo_sitemap_run.php action=sitemap_run ID=2 lang=ru
