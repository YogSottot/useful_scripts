#!/bin/sh
set -e

doc_root=$1
name=$2
if [ -z ${doc_root} ]; then
	echo Usage: $0 /path/to/document/root [backup_name]
	exit
fi

if [ -z ${name} ]; then
	name=`/bin/hostname`
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

cd ${doc_root} && nice -n 19 ionice -c2 -n7 tar czf - --exclude 'bitrix/tmp/*' --exclude 'bitrix/updates/*' --exclude 'bitrix/backup/*' --exclude 'bitrix/*cache/*' --exclude 'bitrix/html_pages/*' --exclude 'upload' bitrix/html_pages/.config.php . | pv -L 10m  | nice -n 19 ionice -c2 -n7 split -a 4 -C 100M -d - ${backup_dir}/${name}.tar.gz_ && nice -n 19 ionice -c2 -n7 /root/.local/bin/swift -q -A https://auth.selcdn.ru -U ${login} -K ${userkey} upload -H "X-Delete-After: 259200" --object-name `date +%Y-%m-%d-%H:%M`/ ${storage_dir} ${backup_dir}/ && rm -rf ${backup_dir}/* && echo OK && exit
echo Error
