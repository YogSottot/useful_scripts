#!/bin/sh
doc_root=$1
name=$2
if [ -z ${doc_root} ]; then
	echo Usage: $0 /path/to/document/root [backup_name]
	exit
fi

if [ -z ${name} ]; then
	name=backup
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
nice -n 19 ionice -c2 -n7 mysqldump -e --add-drop-table --add-locks --skip-lock-tables --single-transaction --quick -h${host} -uroot --default-character-set=${charset} ${database} | pv -L 10m  | nice -n 19 ionice -c2 -n7 xz -C crc32 -0 | split -a 4 -C 100M -d - ${backup_dir}/${name}.sql.xz_


function getValueFromINI() {
	local sourceData=$1; local paramName=$2;
	## 1. Get value "platform=%OUR_VALUE%"
	## 2. Remove illegal characters
	echo $(echo "$sourceData" | sed -n '/^'${paramName}'\ =\(.*\)$/s//\1/p' | tr -d "\r" | tr -d "\n");
}

sectionContent=$(sed -n '/^\[cloud\]/,/^\[/p' /opt/sMonit/config.ini | sed -e '/^\[/d' | sed -e '/^$/d');
login=$(getValueFromINI "$sectionContent" "login");
userkey=$(getValueFromINI "$sectionContent" "password");
storage_dir=$(getValueFromINI "$sectionContent" "dir");

/opt/backup/supload.sh -u ${login} -k ${userkey} -d 48h -r ${storage_dir}/`date +%Y-%m-%d-%H:%M`_DB_Only ${backup_dir} && rm -rf ${backup_dir}/${name}.sql.xz_* && echo OK && exit
echo Error
