#!/usr/bin/env bash
set -eo pipefail

mail="$1"
name="$2"

SCRIPT_NAME="$(basename ${BASH_SOURCE[0]})"

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

cd /opt/backup
nice -n 19 ionice -c2 -n7 \
sudo -u postgres pg_dumpall | \
nice -n 19 ionice -c2 -n7 gzip > ${backup_dir}/postgresql_${name}.sql.gz 2>/tmp/"${SCRIPT_NAME}"_"${database}"_log 
nice -n 19 ionice -c2 -n7 /usr/bin/swift -v -A https://auth.selcdn.ru -U ${login} -K "${userkey}" upload -H "X-Delete-After: 604800" --object-name `date +%Y-%m-%d-%H:%M`_DB_daily_"${name}"/ ${storage_dir} ${backup_dir}/ >> /tmp/"${SCRIPT_NAME}"_"${database}"_log 2>&1

exitcode="$?"

# output
if [ "${exitcode}" -ne "0" ]; then
    mailx -s "$(echo -e  "Backup bitrixdb daily for ${name} is error\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/"${SCRIPT_NAME}"_"${database}"_log
else
    mailx -s "$(echo -e  "Backup bitrixdb daily for ${name} is succesfull\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/"${SCRIPT_NAME}"_"${database}"_log
fi

rm -rf ${backup_dir}/*
exit 0

# restore
# sudo -u postgres psql -U postgres  < dumpall_clean.sql

