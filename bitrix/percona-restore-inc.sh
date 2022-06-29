#!/usr/bin/env bash
set -eo pipefail

incremental_backup="$1"
full_basedir="$2"

if [ -z ${incremental_backup} ]; then
	echo Usage: $0 /opt/backup/inc/incremental_name /opt/backup/db/
	exit
fi

if [ -z ${full_basedir} ]; then
	name=/opt/backup/db/
fi

# decompress base
xtrabackup --decompress --remove-original --target-dir=${full_basedir}
# decompress inc1
xtrabackup --decompress --remove-original --target-dir=${incremental_backup}

# prepare aply-log in base
xtrabackup --prepare --apply-log-only --target-dir=${full_basedir}
# prepare with incremental
xtrabackup --prepare --target-dir=${full_basedir} --incremental-dir=${incremental_backup}

# restore
systemctl stop mysql
mv /var/lib/mysql /var/lib/mysql.old
xtrabackup --move-back --target-dir=${full_basedir}
chown -R mysql:mysql /var/lib/mysql
systemctl start mysql

#if one db
#xtrabackup --prepare --export 
