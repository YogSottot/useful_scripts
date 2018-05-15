#!/usr/bin/env bash

# for whitelist files
# cksum /patch/to/file
# put filename{tab}cksum to .aignore_usr

mail=$1
path="/opt/av/abh/"
hostname=`/bin/hostname`

# make dir for results
if [ ! -d ${path}reports/ ] ; then mkdir -p ${path}reports/; fi

# scan
output=`nice -n 19 ionice -c2 -n7 /usr/bin/php ${path}ai-bolit/ai-bolit-hoster.php --report=${path}reports/REPORT-@DATE@.html --mode=1 --path=/home/bitrix/`
exitcode=$?

# clean reports older then 14 day
cleanrep=`find ${path}reports/ -type f -mtime +14 -exec rm {} \;`

# got recent report
for file in ${path}reports/*; do
  [[ ${file} -nt ${recent_report} ]] && recent_report=${file}
done

# output
if [ "${exitcode}" = "0" ]; then
    ${cleanrep}
    exit 0
fi

if [ "${exitcode}" = "1" ]; then
    mailx -s "$(echo -e  "Virus detected on ${hostname}\nContent-Type: text/html")" ${mail} < ${recent_report}
    ${cleanrep}
fi

if [ "${exitcode}" = "2" ]; then
    mailx -s "$(echo -e  "Virus detected on ${hostname}\nContent-Type: text/html")" ${mail} < ${recent_report}
    ${cleanrep}
fi

exit 0
