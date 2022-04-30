#!/usr/bin/env bash
set -e
source_ssh_host="$1"
source_dir="$2"

target_dir="$3"

printf "Check bx versions\n"
/opt/backup/compare_bx_version.sh ${source_ssh_host} ${source_dir} ${target_dir}

printf "Start percona backup\n"
ssh ${source_ssh_host} "/opt/backup/percona-db.sh"

printf "Start percona rsync\n"
rsync -a ${source_ssh_host}:/opt/backup/db /opt/backup

printf "Start percona restore\n"
/opt/backup/percona-restore.sh

printf "Start mysql_upgrade\n"                                                                                                                                                            
/usr/bin/mysql_upgrade

printf "Update db settings after restore\n"
/opt/backup/update_db.sh ${target_dir}

printf "Remove managed_cache\n"
rm -rf ${target_dir}/bitrix/managed_cache/*

printf "Start rsync upload\n"
rsync -a ${source_ssh_host}:${source_dir}/upload/ ${target_dir}/upload/ --delete
printf "Rsync upload finished!\n"
