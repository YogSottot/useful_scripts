#!/bin/sh
set -e

doc_root=$1

if [ -z ${doc_root} ]; then
	echo Usage: $0 /path/to/document/root
	exit
fi

backup_dir=${doc_root}/bitrix/backup

if [ ! -e ${backup_dir} ]; then
	mkdir ${backup_dir}
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

nice -n 19 ionice -c2 -n7 /usr/bin/php -f /opt/backup/backup-db.php ${doc_root} && nice -n 19 ionice -c2 -n7 /usr/bin/swift -q -A https://auth.selcdn.ru -U ${login} -K ${userkey} upload -H "X-Delete-After: 259200" --object-name `date +%Y-%m-%d-%H:%M`_DB_Only/ ${storage_dir} ${backup_dir}/ ; rm -rf ${backup_dir}/* && echo OK && exit
echo Error
