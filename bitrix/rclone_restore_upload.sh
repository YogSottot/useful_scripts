#!/bin/sh
doc_root=$1

if [ -z ${doc_root} ]; then
	echo Usage: $0 /path/to/document/root [backup_name]
	exit
fi

backup_dir=${doc_root}/upload

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

chmod 644 /opt/backup/rclone.conf

# to restore with bitrix owner
sudo -i -u bitrix bash << EOF
~/.local/bin/rclone --config=/opt/backup/rclone.conf sync selectel:${storage_dir}/upload ${backup_dir} && echo OK && exit
echo Error
EOF

chmod 600 /opt/backup/rclone.conf
