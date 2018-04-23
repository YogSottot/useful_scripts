#!/usr/bin/env bash

mode=$1
search_path=$2
mail=$3
hostname=`/bin/hostname`

# check for arguments
if [ ! $1 ] || [ ! $2 ] || [ ! $3 ] ; then
    echo "Syntax: mode (1 or 2) search_path mail_for_report"
    echo;exit
fi

path="/opt/av/abm/"
if [ ! -d  ${path} ]; then { mkdir -p ${path}; } fi

# update
rm -f ${path}abm.zip
wget -P ${path}  http://bit.ly/2EFBqgm -O ${path}abm.zip
unzip -o ${path}abm.zip -d $path

# make dir for results
if [  ! -d ${path}reports/ ] ; then mkdir -p ${path}reports/; fi

# scan
output=`/usr/bin/php ${path}ai-bolit/ai-bolit.php --report=${path}reports/REPORT-@DATE@.html --mode=${mode} --path=${search_path}`
exitcode=$?

# got recent report
for file in ${path}reports/*; do
  [[ ${file} -nt ${recent_report} ]] && recent_report=$file
done

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
