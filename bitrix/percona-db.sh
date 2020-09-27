#!/bin/sh
set -e

rm -rf /opt/backup/db.prev
mv /opt/backup/db /opt/backup/db.prev

xtrabackup --backup --lock-ddl --compress --target-dir=/opt/backup/db
