#!/bin/sh
doc_root=$1
name=$2
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

backup_dir=${doc_root}/bitrix/backup

if [ ! -e ${backup_dir} ]; then
	mkdir ${backup_dir}
fi

cd ${doc_root} &&
nice -n 19 ionice -c2 -n7 mysqldump -e --add-drop-table --add-locks --skip-lock-tables --single-transaction --quick -h${host} -uroot --default-character-set=${charset} ${database} | pv -L 10m  | nice -n 19 ionice -c2 -n7 gzip | split -a 4 -C 100M -d - ${backup_dir}/${name}.sql.gz_


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

nice -n 19 ionice -c2 -n7 /root/.local/bin/swift -q -A https://auth.selcdn.ru -U ${login} -K ${userkey} upload -H "X-Delete-After: 172800" --object-name `date +%Y-%m-%d-%H:%M`_DB_Only/ ${storage_dir} ${backup_dir}/ && rm -rf ${backup_dir}/* && echo OK && exit
echo Error
