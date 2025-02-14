#!/usr/bin/env bash
set -eo pipefail
# https://github.com/mydumper/mydumper_repo

source_ssh_host="$1"
source_dir="$2"
target_dir="$3"
dev_domain="$4"
admins_file="/opt/backup/devadmins.txt"

printf "Check bx versions\n"
/opt/backup/compare_bx_version.sh ${source_ssh_host} ${source_dir} ${target_dir}

printf "Start mydumper backup\n"
ssh ${source_ssh_host} "/opt/backup/mydumper_bitrixdb_manual.sh ${source_dir}"

printf "Start rsync db\n"
rsync -a ${source_ssh_host}:/opt/backup/mydumper /opt/backup/
printf "Delete dump db from source\n"
ssh ${source_ssh_host} "rm -rf /opt/backup/mydumper/"

printf "Start myloader restore\n"
/opt/backup/myloader_bitrixdb_manual.sh ${target_dir}
printf "Delete dump db from target\n"
rm -rf /opt/backup/mydumper

printf "Start update db settings\n"
/opt/backup/update_db.sh ${target_dir} ${dev_domain}

printf "Add developers accounts"
php /opt/backup/devadmins.php ${target_dir} ${admins_file}

printf "Remove cache dirs\n"
rm -rf ${target_dir}/bitrix/managed_cache/*
rm -rf ${target_dir}/bitrix/cache/*
rm -rf ${target_dir}/bitrix/stack_cache/*

# Comparisons:
#  -eq   equal to
#  -ne   not equal to
#  -lt   less than
#  -le   less than or equal to
#  -gt   greater than
#  -ge   greater than or equal to

# help test
# "if -f" operator returns true if file exists and is not a directory
# "if -e” statement, produces a “true” output if any specified file exists
# “if -s” operator returns true if a file exists and also if it is not empty
# "if -d” operator returns true if your file is a directory
# “if -h” operator returns true if your file is a symbolic link
# "if -w" operator will be true if the current user can write the file
# “if -r” operator will be true if the current user can read the file
# “if -O” operator will be true if the current user owns the file
# “if -x” operator will be true if the file is executable

if [ -s /etc/sysconfig/memcached ] || [ -s /etc/default/memcached ]; then
    printf "Restart memcached\n"
    systemctl restart memcached
fi

# rsync upload
printf "Start rsync upload\n"
rsync -a ${source_ssh_host}:${source_dir}/upload/ ${target_dir}/upload/ --delete
# full sync for stage
# rsync --exclude '/robots.txt' --exclude '/bitrix/cache/*' --exclude '/bitrix/backup/*' --exclude '/bitrix/managed_cache/*'  --exclude '/bitrix/stack_cache/*' --exclude '/bitrix/html_pages/*' --exclude '/bitrix/.settings.php' --exclude '/bitrix/.settings_extra.php' --exclude '/bitrix/php_interface/dbconn.php'  -a ${source_ssh_host}:${source_dir}/ ${target_dir}/ --delete
# full sync for ext_site
# rsync --exclude '/robots.txt'  --exclude '/bitrix' --exclude '/images'  --exclude '/upload' -a ${source_ssh_host}:/home/bitrix/ext_www/domain.tld/ /home/bitrix/ext_www/domain.tld/ --delete
printf "Rsync upload finished!\n"

printf "Sync finished succesfull!\n"

# add into /root/.my.cnf
# [mydumper]
# user=
# password=
# socket=/var/lib/mysqld/mysqld.sock

# [myloader]
# user=
# password=
#socket=/var/lib/mysqld/mysqld.sock
