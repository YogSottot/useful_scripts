#!/bin/sh
set -e

doc_root=$1
backup_name=`/bin/hostname`
if [ -z ${doc_root} ]; then
	echo Usage: $0 /path/to/document/root [backup_name]
	exit
fi

if [ -z ${backup_name} ]; then
	backup_name=backup
fi

backup_dir=${doc_root}/bitrix/backup

if [ ! -e ${backup_dir} ]; then
	mkdir ${backup_dir}
fi

# xtrabackup --stream=tar ./ | gzip - > backup.tar.gz
# or
# --parallel=4 --compress-threads=2 --databases --throttle=
xtrabackup --backup --stream=xbstream --compress --tmp-dir=${backup_dir} > ${backup_dir}/${backup_name}.xbstream

# add passwords for bd
cp /root/.my.cnf ${backup_dir}/
cp ${doc_root}/bitrix/.settings.php ${backup_dir}/

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

nice -n 19 ionice -c2 -n7 /root/.local/bin/swift -q -A https://auth.selcdn.ru -U ${login} -K ${userkey} upload -H "X-Delete-After: 172800" --object-threads 1 --object-name `date +%Y-%m-%d-%H:%M`_Percona/ ${storage_dir} ${backup_dir}/ ; rm -rf ${backup_dir}/* && rm -rf ${backup_dir}/.my.cnf && rm -rf ${backup_dir}/.settings.php && echo OK && exit
echo Error
