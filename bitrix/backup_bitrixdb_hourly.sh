#!/bin/sh

doc_root=$1
name=$2

SCRIPT_NAME="$(basename ${BASH_SOURCE[0]})"

if [ -z ${doc_root} ]; then
	echo Usage: $0 /path/to/document/root [backup_name]
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

#backup_dir=${doc_root}/bitrix/backup
backup_dir=/opt/backup/backup

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

sectionContent=$(sed -n '/^\[cloud\]/,/^\[/p' /opt/sMonit/config.ini | sed -e '/^\[/d' | sed -e '/^$/d');
login=$(getValueFromINI "$sectionContent" "login");
userkey=$(getValueFromINI "$sectionContent" "password");
storage_dir=$(getValueFromINI2 "$sectionContent" "dir");

cd ${doc_root} && \
nice -n 19 ionice -c2 -n7 \
mysqldump -e --add-drop-table --add-locks \
--skip-lock-tables --single-transaction --quick \
-h${host} -uroot --default-character-set=${charset} \
${database} | pv -L 10m  | \
nice -n 19 ionice -c2 -n7 gzip > ${backup_dir}/${name}.sql.gz > /tmp/"${SCRIPT_NAME}"_log 2>&1 && \
nice -n 19 ionice -c2 -n7 /root/.local/bin/swift -q -A https://auth.selcdn.ru -U ${login} -K ${userkey} upload -H "X-Delete-After: 129600" --object-name `date +%Y-%m-%d-%H:%M`_DB_Only_hourly/ ${storage_dir} ${backup_dir}/ >> /tmp/"${SCRIPT_NAME}"_log 2>&1

exitcode="$?"

# output
if [ "${exitcode}" -ne "0" ]; then
    mailx -s "$(echo -e  "Backup bitrixdb hourly on ${hostname} is error\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/"${SCRIPT_NAME}"_log
fi

rm -rf ${backup_dir}/*
exit 0
