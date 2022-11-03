#!/usr/bin/env bash
set -eo pipefail

command=`mysql -e 'show processlist;' | grep PREVIEW_PICTURE | grep -Eo "^[[:digit:]]{1,16}" | awk '{print "kill "$1";"}'`
for i in ${command} ; do
 mysql -e "$command"
done
