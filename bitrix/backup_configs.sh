#!/usr/bin/env bash
set -o pipefail

doc_root=$1
if [ -z ${doc_root} ]; then
	echo Usage: $0 /path/to/document/root
	exit
fi

name="$2"

if [ -z ${name} ]; then
	name=`/bin/hostname`
fi


#backup_dir=${doc_root}/bitrix/backup
backup_dir=/opt/backup/backup_"${name}"

if [ ! -e ${backup_dir} ]; then
	mkdir ${backup_dir}
fi

tar cfp - -C /etc/ nginx/ | gzip -c > ${backup_dir}/nginx.tgz
tar cfp - -C /etc/ httpd/ | gzip -c > ${backup_dir}/httpd.tgz
tar cfp - -C /etc/ php.d/ | gzip -c > ${backup_dir}/phpd.tgz
tar cfp - -C /etc/ mysql/ | gzip -c > ${backup_dir}/mysql.tgz
tar cfp - -C /var/spool/ cron/ | gzip -c > ${backup_dir}/cron.tgz
tar cfp - -C /opt/backup/ restic/ | gzip -c > ${backup_dir}/restic.tgz
tar cfp - -C /opt/backup/ scripts | gzip -c > ${backup_dir}/backup_scripts.tgz
tar cfp - -C /etc/ logrotate.d/ | gzip -c > ${backup_dir}/logrotate.d.tgz
tar cfp - -C /etc/ sysconfig/ | gzip -c > ${backup_dir}/sysconfig.tgz
tar cfp - -C /home/bitrix/ .ssh/ | gzip -c > ${backup_dir}/bitrix_ssh.tgz
tar cfp - -C /root/.ssh/config | gzip -c > ${backup_dir}/root_ssh_config.tgz
tar cfp - -C /etc/ systemd/ | gzip -c > ${backup_dir}/systemd.tgz
tar cfp - -C /etc/ sudoers.d/ | gzip -c > ${backup_dir}/sudoers.tgz
tar cfp - -C /etc/ zabbix/ | gzip -c > ${backup_dir}/zabbix.tgz

php -v > ${backup_dir}/php_version.txt
cd ${doc_root} && cd bitrix/html_pages/ && tar cfpz ${backup_dir}/composite_config.tgz .config.php

cd ${backup_dir}
tar cfp configs.tar *.tgz
rm -f *.tgz
# for site links
# /usr/bin/tar cfp - -C /home/bitrix/ext_www/ dev.domain.tld/ | gzip -c > ${backup_dir}/dev.domain.tld_`date +%Y.%m.%d-%H.%M`.tgz 
# tar cfp - --exclude=www/bitrix/tmp/* --exclude=www/bitrix/updates/* --exclude=www/bitrix/backup/* --exclude=www/bitrix/*cache/* --exclude=www/bitrix/html_pages/*  -C /home/bitrix/ www/ | gzip -c > ${backup_dir}/${name}_files_`date +%Y.%m.%d-%H.%M`.tar.gz
