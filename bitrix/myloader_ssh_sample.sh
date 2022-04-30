#!/usr/bin/env bash
set -e
# https://github.com/mydumper/mydumper/releases
# yum install libzstd -y

source_ssh_host="$1"
source_dir="$2"

target_ssh_host="$3"
target_dir="$4"

printf "Check bx versions\n"
/opt/backup/compare_bx_version.sh ${source_ssh_host} ${source_dir} ${target_dir}

printf "Start mydumper backup\n"
ssh ${source_ssh_host} "/opt/backup/mydumper_bitrixdb_manual.sh ${source_dir} ${target_ssh_host}"

printf "Start myloader restore\n"
/opt/backup/mydumper_bitrixdb_manual.sh ${target_dir}
rm -rf /opt/backup/mydumper

printf "Start update db settings\n"
# disable auto backup
/opt/backup/update_db.sh ${target_dir}

# clean mysql cache
printf "Clean mysql cache\n"
rm -rf ${target_dir}/bitrix/managed_cache/*

# rsync upload
printf "Start rsync upload\n"
rsync -a ${source_ssh_host}:${source_dir}/upload/ ${target_dir}/upload/ --delete
printf "Rsync upload finished!\n"
