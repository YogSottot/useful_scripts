#!/bin/sh
set -e

mkdir -p /opt/backup/inc/
# delete inc older then 15 hours
/usr/bin/find /opt/backup/inc/ -mindepth 1 -maxdepth 1 -type d -mmin +900 -exec rm -rf {} \;
# make inc backup for the current base
xtrabackup --backup --lock-ddl --compress --target-dir=/opt/backup/inc/`date +%Y-%m-%d-%H:%M` --incremental-basedir=/opt/backup/db
