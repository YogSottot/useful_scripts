#!/bin/bash

# apt install awscli percona-xtrabackup

# Configuration
S3_BUCKET="your_bucket"
DATE=$(date +%Y-%m-%d)
BACKUP_NAME=${2:-$(hostname)}
FULL_BACKUP_NAME="${BACKUP_NAME}_full_backup_${DATE}.xbstream.zst"
INC_BACKUP_NAME="${BACKUP_NAME}_inc_backup_${DATE}.xbstream.zst"
RETENTION_DAYS=14

# Functions
cleanup_old_backups() {
    echo "Cleaning up old backups..."
    aws s3 ls s3://$S3_BUCKET/ | grep -E "${BACKUP_NAME}_full_backup_|${BACKUP_NAME}_inc_backup_" | while read -r backup; do
        backup_date=$(echo $backup | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
        backup_timestamp=$(date -d $backup_date +%s)
        cutoff_timestamp=$(date -d "$RETENTION_DAYS days ago" +%s)
        if [[ $backup_timestamp -lt $cutoff_timestamp ]]; then
            echo "Deleting old backup: $backup"
            aws s3 rm s3://$S3_BUCKET/$backup
        fi
    done
}

perform_full_backup() {
    echo "Performing full backup..."
    xtrabackup --backup --stream=xbstream | zstd | aws s3 cp - s3://$S3_BUCKET/$FULL_BACKUP_NAME
}

perform_incremental_backup() {
    echo "Performing incremental backup..."
    LAST_FULL_BACKUP=$(aws s3 ls s3://$S3_BUCKET/ | grep "${BACKUP_NAME}_full_backup_" | tail -n 1 | awk '{print $4}')
    aws s3 cp s3://$S3_BUCKET/$LAST_FULL_BACKUP - | zstd -d | xbstream -x -C /tmp/last_full_backup
    xtrabackup --backup --stream=xbstream --incremental-basedir=/tmp/last_full_backup | zstd | aws s3 cp - s3://$S3_BUCKET/$INC_BACKUP_NAME
    rm -rf /tmp/last_full_backup
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
