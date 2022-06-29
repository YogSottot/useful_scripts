#!/usr/bin/env bash
set -eo pipefail

basedir=/home/bitrix/www/logs
destdir=${basedir} # if you want rotated files in the same directories
#destdir=/var/log/archivedir/ #if you want rotated files somewhere else
config_file=/etc/logrotate.d/bitrix
> ${config_file} #clear existing config_file contents

subfolders="$(find ${basedir} -type d)"

for ii in ${subfolders}
do
    jj=${ii:${#basedir}} #strip off basedir, jj is the relative path

    #append new entry to config_file
    echo "${basedir}${jj}/*.log {
        olddir ${destdir}${jj}/
        su bitrix bitrix
        daily
        dateext
        dateformat .%Y-%m-%d
        rotate 30
        copytruncate
        notifempty
        missingok
        compress
        maxage 30
        sharedscripts
        }
        " >> ${config_file}

    #add one line as spacing between entries
#    echo '\n' >> ${config_file}

    #create destination folder, if it doesn't exist
    [ -d ${destdir}${jj} ] || mkdir ${destdir}${jj}
done
