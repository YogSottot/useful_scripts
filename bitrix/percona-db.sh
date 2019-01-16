#!/bin/sh
set -eu

rm -rf /opt/backup/db.prev
mv /opt/backup/db /opt/backup/db.prev

xtrabackup --backup --compress --target-dir=/opt/backup/db
