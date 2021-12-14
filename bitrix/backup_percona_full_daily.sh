#!/bin/sh

backup_dir="$1"
mail="$2"
name="$3"
hostname=`/bin/hostname`

SCRIPT_NAME="$(basename ${BASH_SOURCE[0]})"

if [ -z ${backup_dir} ]; then
	echo Usage: $0 /opt/backup mail [backup_name]
	exit
fi

if [ -z ${name} ]; then
	name=db
fi

SCRIPTNAME=$(basename $0)
LOCKDIR="/var/lock/percona"
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

if [ ! -e ${backup_dir}/${name} ]; then
	mkdir -p ${backup_dir}/${name}
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

rm -rf ${backup_dir}/${name}.prev && \
mv ${backup_dir}/${name} ${backup_dir}/${name}.prev && \

nice -n 19 ionice -c2 -n7 \
xtrabackup --backup --lock-ddl --compress --target-dir=${backup_dir}/${name} > /tmp/"${SCRIPT_NAME}"_"${name}"_log 2>&1

# nice -n 19 ionice -c2 -n7 /root/.local/bin/swift -v -A https://auth.selcdn.ru -U ${login} -K ${userkey} upload -H "X-Delete-After: 604800" --object-name `date +%Y-%m-%d-%H:%M`_DB_percona_daily_"${name}"/ ${storage_dir} ${backup_dir}/${name}/ > /tmp/"${SCRIPT_NAME}"_"${database}"_log 2>&1

exitcode="$?"

# output
if [ "${exitcode}" -ne "0" ]; then
    mailx -s "$(echo -e  "Backup percona daily for ${hostname} is error\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/"${SCRIPT_NAME}"_"${name}"_log
else
    mailx -s "$(echo -e  "Backup percona daily for ${hostname} is succesfull\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/"${SCRIPT_NAME}"_"${name}"_log
fi

exit 0
