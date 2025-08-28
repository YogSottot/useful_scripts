#!/usr/bin/env bash
set -eo pipefail

source_ssh_host="$1"
source_dir="$2"
target_dir="$3"
dev_domain="$4"
admins_file="/opt/backup/devadmins.txt"
domain_list="/opt/backup/domain_list.txt"

printf "Check bx versions\n"
/opt/backup/compare_bx_version.sh ${source_ssh_host} ${source_dir} ${target_dir}

printf "Start percona backup\n"
ssh ${source_ssh_host} "/opt/backup/percona-db.sh"

printf "Start percona rsync\n"
rsync -a ${source_ssh_host}:/opt/backup/db /opt/backup

printf "Start percona restore\n"
/opt/backup/percona-restore.sh

printf "Delete dump db from source\n"
ssh ${source_ssh_host} "rm -rf /opt/backup/db"

printf "Delete dump db from target\n"                                                                                                                 
rm -rf /opt/backup/db

printf "Start mysql_upgrade\n"
/usr/bin/mysql_upgrade

printf "Update db settings after restore\n"
php /opt/backup/update_db.php "${target_dir}" "${dev_domain}" "${domain_list}"

printf "Add developers accounts"
php /opt/backup/devadmins.php ${target_dir} ${admins_file}

printf "Remove cache dirs\n"
rm -rf ${target_dir}/bitrix/managed_cache/*
rm -rf ${target_dir}/bitrix/cache/*
rm -rf ${target_dir}/bitrix/stack_cache/*

# "if -e” statement, produces a “true” output if any specified file exists
# “if -s” operator returns true if a file exists and also if it is not empty
# "if -d” operator returns true if your file is a directory
# “if -h” operator returns true if your file is a symbolic link
# “if -r” operator will be true if the current user can read the file
# “if -O” operator will be true if the current user owns the file
if [ -s /etc/sysconfig/memcached ]; then
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
