#!/usr/bin/env bash
set -eo pipefail

ulimit -n 1048576

MYSQL_VER="$(mysql --version 2>/dev/null || true)"

if echo "$MYSQL_VER" | grep -qi "MariaDB"; then

    rm -rf /opt/backup/db.xb.zst
    mariadb-backup --lock-ddl-per-table --backup --stream=xbstream  | zstd - -o /opt/backup/db.xb.zst -f -1
    
else
    rm -rf /opt/backup/db.prev
    mv /opt/backup/db /opt/backup/db.prev

    xtrabackup --backup --lock-ddl --compress --target-dir=/opt/backup/db
fi
