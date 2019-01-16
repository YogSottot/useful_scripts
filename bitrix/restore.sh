#!/bin/sh
set -eu

doc_root=$1
name=$2
if [ -z ${doc_root} ]; then
	echo Usage: $0 /path/to/document/root [backup_name]
	exit
fi

if [ -z ${name} ]; then
	name=backup
fi

cat ${name}.sql.xz_* | xz -d > ${name}.sql && rm -rf ${name}.sql.xz_*

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

mysql -h${host} -uroot --default-character-set=${charset} ${database} < ${name}.sql
