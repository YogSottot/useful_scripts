#!/usr/bin/env bash
set -eo pipefail

# Backup mailcow data
# https://docs.mailcow.email/backup_restore/b_n_r-backup/

mail="$1"
name="$3"

HC_UUID="$2"
HC_BASE_URL="https://hc.s-webs.ru/ping"
HC_URL=$HC_BASE_URL/$HC_UUID

# Generate Run IDs
RID=$(uuidgen)

# On start script
curl -fsS -m 30 --retry 5 "${HC_URL}/start?rid=$RID"

if [ -z ${name} ]; then
	name=`/bin/hostname`
fi

OUT="$(mktemp)"
export MAILCOW_BACKUP_LOCATION="/opt/backup/data/"
SCRIPT="/opt/mailcow-dockerized/helper-scripts/backup_and_restore.sh"
PARAMETERS="backup all"
OPTIONS="--delete-days 1"

# run command
set +e
"${SCRIPT}" ${PARAMETERS} ${OPTIONS} 2>&1 > "$OUT"
RESULT=$?

if [ $RESULT -ne 0 ]
    then
            echo "${SCRIPT} ${PARAMETERS} ${OPTIONS} encounters an error:"
            echo "RESULT=$RESULT"
            echo "STDOUT / STDERR:"
            cat "$OUT"
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

sectionContent=$(sed -n '/^\[cloud\]/,/^\[/p' /opt/backup/scripts/config.ini | sed -e '/^\[/d' | sed -e '/^$/d');
login=$(getValueFromINI "$sectionContent" "login");
userkey=$(getValueFromINI "$sectionContent" "password");
storage_dir=$(getValueFromINI2 "$sectionContent" "dir");

nice -n 19 ionice -c2 -n7 /root/.local/bin/swift -v --os-auth-url "${url}" --auth-version 3 --os-project-id "${project}" --os-user-id "${login}" --os-password "${password}" upload -H "X-Delete-After: 864000" --object-name `date +%Y-%m-%d-%H:%M`_daily_"${name}"/ ${storage_dir} ${MAILCOW_BACKUP_LOCATION}/ > /tmp/"${SCRIPT_NAME}"_"${name}"_log 2>&1

exitcode="$?"

# On end script with exit code and run ID
curl -fsS -m 30 --retry 5 --data-binary @/tmp/"${SCRIPT_NAME}"_"${name}"_log "${HC_URL}/${exitcode}?rid=$RID"

# output
if [ "${exitcode}" -ne "0" ]; then
    mailx -s "$(echo -e  "Backup bitrixdb daily for ${name} is error\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/"${SCRIPT_NAME}"_"${name}"_log
else
    mailx -s "$(echo -e  "Backup bitrixdb daily for ${name} is succesfull\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/"${SCRIPT_NAME}"_"${name}"_log
fi

rm -rf ${MAILCOW_BACKUP_LOCATION}/*
exit 0
