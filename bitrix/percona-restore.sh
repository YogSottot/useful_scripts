#!/usr/bin/env bash
set -eo pipefail

ulimit -n 1048576

mkdir -p /opt/backup/db

MYSQL_VER="$(mysql --version 2>/dev/null || true)"

if echo "$MYSQL_VER" | grep -qi "MariaDB"; then

    # decompress
    zstd -d /opt/backup/db.xb.zst -c | mbstream -x -C /opt/backup/db
    
    # prepare
    mariadb-backup --prepare --target-dir=/opt/backup/db
    
    # remove old db
    systemctl stop mysql
    rm -rf /var/lib/mysql

    # restore
    mariadb-backup --move-back --target-dir=/opt/backup/db
    chown -R mysql:mysql /var/lib/mysql
    systemctl start mysql

else
    # decompress    
    xtrabackup --decompress --remove-original --target-dir=/opt/backup/db
    # prepare
    xtrabackup --prepare --target-dir=/opt/backup/db

    # remove old db
    systemctl stop mysql
    mv /var/lib/mysql /var/lib/mysql.old

    # restore
    xtrabackup --move-back --target-dir=/opt/backup/db
    chown -R mysql:mysql /var/lib/mysql
    systemctl start mysql

    #if one db
    #xtrabackup --prepare --export 
fi
