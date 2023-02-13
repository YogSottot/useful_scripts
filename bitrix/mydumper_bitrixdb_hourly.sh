#!/usr/bin/env bash
set -eo pipefail
# https://github.com/mydumper/mydumper/releases
# yum install libzstd -y 

doc_root="$1"
mail="$2"
name="$3"

cpu=`nproc --ignore=1`

SCRIPT_NAME="$(basename ${BASH_SOURCE[0]})"

if [ -z ${doc_root} ]; then
	echo Usage: $0 /path/to/document/root mail [backup_name]
	exit
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
#backup_dir=/opt/backup/mydumper
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

sectionContent=$(sed -n '/^\[cloud\]/,/^\[/p' /opt/backup/config.ini | sed -e '/^\[/d' | sed -e '/^$/d');
login=$(getValueFromINI "$sectionContent" "login");
userkey=$(getValueFromINI "$sectionContent" "password");
storage_dir=$(getValueFromINI2 "$sectionContent" "dir");

nice -n 19 ionice -c2 -n7 \
mydumper --threads "${cpu}" --compress --less-locking --use-savepoints  --regex "^(?=(?:(${database}\.)))(?!(?:(${database}\.b_stat|${database}\.b_search|${database}\.b_event_log$|${database}\.b_composite)))" --outputdir "${backup_dir}"  > /tmp/"${SCRIPT_NAME}"_"${database}"_log 2>&1

mydumper --threads "${cpu}" --compress --less-locking --use-savepoints --no-data --regex "^(${database}\.b_stat|${database}\.b_search|${database}\.b_event_log$|${database}\.b_composite)" --outputdir "${backup_dir}"   >> /tmp/"${SCRIPT_NAME}"_"${database}"_log 2>&1

mydumper --version > "${backup_dir}"/mydumper_version

nice -n 19 ionice -c2 -n7 /root/.local/bin/swift -v -A https://auth.selcdn.ru -U ${login} -K ${userkey} upload -H "X-Delete-After: 129600" --object-name `date +%Y-%m-%d-%H:%M`_DB_hourly_"${name}"/ ${storage_dir} ${backup_dir}/ >> /tmp/"${SCRIPT_NAME}"_"${database}"_log 2>&1

exitcode="$?"

# output
if [ "${exitcode}" -ne "0" ]; then
    mailx -s "$(echo -e  "Backup MYDUMPER hourly for ${name} is Error\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/"${SCRIPT_NAME}"_"${database}"_log
fi

rm -rf ${backup_dir}/*
exit 0
