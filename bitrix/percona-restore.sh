#!/bin/sh

xtrabackup --decompress --remove-original --target-dir=/opt/backup/db
xtrabackup --prepare --target-dir=/opt/backup/db
systemctl stop mysql
mv /var/lib/mysql /var/lib/mysql.old
xtrabackup --move-back --target-dir=/opt/backup/db
chown -R mysql:mysql /var/lib/mysql
systemctl start mysql

#if one db
#xtrabackup --prepare --export 
