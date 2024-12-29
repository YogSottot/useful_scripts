#!/usr/bin/env bash
set -eo pipefail

source_ssh_host="$1"
source_dir="$2"
target_dir="$3"
mail="$4"

HC_UUID="$5"
HC_BASE_URL="https://healthchecks.io/ping"
HC_URL=$HC_BASE_URL/$HC_UUID

# Generate Run IDs
RID=$(uuidgen)

# On start script
curl -fsS -m 30 --retry 5 "${HC_URL}/start?rid=$RID"

SCRIPTNAME=$(basename $0)

/opt/backup/myloader_ssh_manual.sh ${source_ssh_host} ${source_dir} ${target_dir} > /tmp/"${SCRIPT_NAME}"_"${source_ssh_host}"_log 2>&1

exitcode="$?"

# On end script with exit code and run ID
curl -fsS -m 30 --retry 5 --data-binary @/tmp/"${SCRIPT_NAME}"_"${source_ssh_host}"_log "${HC_URL}/${exitcode}?rid=$RID"

# output
if [ "${exitcode}" -ne "0" ]; then
    mailx -s "$(echo -e  "Backup MYDUMPER Monthly for ${name} is Error\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/"${SCRIPT_NAME}"_"${source_ssh_host}"_log
else
    mailx -s "$(echo -e  "Backup MYDUMPER Monthly for ${name} is Succesfull\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/"${SCRIPT_NAME}"_"${source_ssh_host}"_log
fi
