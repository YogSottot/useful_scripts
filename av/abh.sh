#!/usr/bin/env bash

mail=$1
path="/opt/av/abh/"
hostname=`/bin/hostname`

# make dir for results
if [ ! -d ${path}reports/ ] ; then mkdir -p ${path}reports/; fi

# scan
output=`nice -n 19 ionice -c2 -n7 /usr/bin/php ${path}ai-bolit/ai-bolit-hoster.php --report=${path}reports/REPORT-@DATE@.html --mode=1 --path=/home/bitrix/`
exitcode=$?

# got recent report
for file in ${path}reports/*; do
  [[ ${file} -nt ${recent_report} ]] && recent_report=${file}
done

# output
if [ "${exitcode}" = "0" ]; then
    exit 0
fi

if [ "${exitcode}" = "1" ]; then
    mailx -s "Virus detected on ${hostname}" ${mail} < ${recent_report}
fi

if [ "${exitcode}" = "2" ]; then
    mailx -s "Virus detected on ${hostname}" ${mail} < ${recent_report}
fi

# delete older then 14 day reports
find ${path}reports/ -type f -mtime +14 -exec rm {} \;

exit 0

# for whitelist files
# cksum /patch/to/file
# put filename{tab}cksum to .aignore_usr
