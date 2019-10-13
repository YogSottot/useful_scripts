#!/bin/sh
set -e

doc_root=$1
if [ -z ${doc_root} ]; then
	echo Usage: $0 /path/to/document/root
	exit
fi

#backup_dir=${doc_root}/bitrix/backup
backup_dir=/opt/backup/backup

if [ ! -e ${backup_dir} ]; then
	mkdir ${backup_dir}
fi

tar cfp - -C /etc/ nginx/ | gzip -c > ${backup_dir}/nginx.tgz
tar cfp - -C /etc/ httpd/ | gzip -c > ${backup_dir}/httpd.tgz
tar cfp - -C /etc/ php.d/ | gzip -c > ${backup_dir}/phpd.tgz
tar cfp - -C /etc/ mysql/ | gzip -c > ${backup_dir}/mysql.tgz
tar cfp - -C /var/spool/ cron/ | gzip -c > ${backup_dir}/cron.tgz
tar cfp - -C /opt/backup/ restic/ | gzip -c > ${backup_dir}/restic.tgz
cd ${backup_dir} && cd bitrix/html_pages/ && tar cfpz ${backup_dir}/composite_config.tgz .config.php

cd ${backup_dir}
tar cfp configs.tar *.tgz
rm -f *.tgz
# for site links
# /usr/bin/tar cfp - -C /home/bitrix/ext_www/ dev.domain.tld/ | gzip -c > ${backup_dir}/dev.domain.tld_`date +%Y.%m.%d-%H.%M`.tgz 
