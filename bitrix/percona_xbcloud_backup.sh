#!/bin/bash

# Configuration
SWIFT_CONTAINER="your_container"
BACKUP_DIR="/tmp/mysql_backup"
FULL_BACKUP_DIR="$BACKUP_DIR/full"
INC_BACKUP_DIR="$BACKUP_DIR/inc"
DATE=$(date +%Y-%m-%d)
FULL_BACKUP_NAME="full_backup_$DATE"
INC_BACKUP_NAME="inc_backup_$DATE"
RETENTION_DAYS=14

# Functions
cleanup_old_backups() {
    echo "Cleaning up old backups..."
    swift list $SWIFT_CONTAINER | grep -E 'full_backup_|inc_backup_' | while read -r backup; do
        backup_date=$(echo $backup | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
        backup_timestamp=$(date -d $backup_date +%s)
        cutoff_timestamp=$(date -d "$RETENTION_DAYS days ago" +%s)
        if [[ $backup_timestamp -lt $cutoff_timestamp ]]; then
            echo "Deleting old backup: $backup"
            swift delete $SWIFT_CONTAINER $backup
        fi
    done
}

perform_full_backup() {
    echo "Performing full backup..."
    mkdir -p $FULL_BACKUP_DIR
    xtrabackup --backup --stream=xbstream --extra-lsndir=$FULL_BACKUP_DIR --target-dir=$FULL_BACKUP_DIR | xbcloud put --storage=swift $SWIFT_CONTAINER/$FULL_BACKUP_NAME
    rm -rf $FULL_BACKUP_DIR
}

perform_incremental_backup() {
    echo "Performing incremental backup..."
    mkdir -p $INC_BACKUP_DIR
    xtrabackup --backup --stream=xbstream --extra-lsndir=$INC_BACKUP_DIR --incremental-basedir=$FULL_BACKUP_DIR --target-dir=$INC_BACKUP_DIR | xbcloud put --storage=swift $SWIFT_CONTAINER/$INC_BACKUP_NAME
    rm -rf $INC_BACKUP_DIR
}

# Main script
day_of_week=$(date +%u)

if [[ $day_of_week -eq 7 ]]; then
    perform_full_backup
else
    perform_incremental_backup
fi

cleanup_old_backups

echo "Backup completed successfully."
