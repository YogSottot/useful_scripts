#!/usr/bin/env bash
set -eo pipefail

source_ssh_host="$1"
source_dir="$2"
target_dir="$3"
mail="$4"

SCRIPTNAME=$(basename $0)

/opt/backup/myloader_ssh_manual.sh ${source_ssh_host} ${source_dir} ${target_dir} > /tmp/"${SCRIPT_NAME}"_"${source_ssh_host}"_log 2>&1

exitcode="$?"

# output
if [ "${exitcode}" -ne "0" ]; then
    mailx -s "$(echo -e  "Backup MYDUMPER Monthly for ${name} is Error\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/"${SCRIPT_NAME}"_"${source_ssh_host}"_log
else
    mailx -s "$(echo -e  "Backup MYDUMPER Monthly for ${name} is Succesfull\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/"${SCRIPT_NAME}"_"${source_ssh_host}"_log
fi
