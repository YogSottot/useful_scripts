#!/bin/sh
doc_root=$1
if [ -z ${doc_root} ]; then
	echo Usage: $0 /path/to/document/root
	exit
fi

backup_dir=${doc_root}/bitrix/backup

if [ ! -e ${backup_dir} ]; then
	mkdir ${backup_dir}
fi

/usr/bin/tar cfp - -C /etc/ nginx/ | gzip -c > ${backup_dir}/nginx.tgz
/usr/bin/tar cfp - -C /etc/ httpd/ | gzip -c > ${backup_dir}/httpd.tgz
/usr/bin/tar cfp - -C /etc/ php.d/ | gzip -c >${backup_dir}/phpd.tgz
/usr/bin/tar cfp - -C /etc/ mysql/ | gzip -c > ${backup_dir}/mysql.tgz
/usr/bin/tar cfp - -C /var/spool/ cron/ | gzip -c > ${backup_dir}/cron.tgz


