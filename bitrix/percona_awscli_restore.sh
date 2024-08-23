#!/bin/bash

# Configuration
S3_BUCKET="your_bucket"
RESTORE_DIR="/tmp/mysql_restore"
MYSQL_DATA_DIR="/var/lib/mysql"
DATE=$1
BACKUP_NAME=${2:-$(hostname)}

# Functions
download_and_extract_backup() {
    local backup_name=$1
    local target_dir=$2
    echo "Downloading and extracting $backup_name..."
    mkdir -p $target_dir
    aws s3 cp s3://$S3_BUCKET/$backup_name - | zstd -d | xbstream -x -C $target_dir
}

apply_backup() {
    local target_dir=$1
    echo "Applying backup from $target_dir..."
    xtrabackup --prepare --apply-log-only --target-dir=$target_dir
}

move_backup() {
    local target_dir=$1
    echo "Moving backup to MySQL data directory..."
    rm -rf $MYSQL_DATA_DIR
    xtrabackup --move-back --target-dir=$target_dir
    chown -R mysql:mysql $MYSQL_DATA_DIR
}

# Main script
if [[ -z "$DATE" ]]; then
    echo "Usage: $0 <date> [backup_name]"
    echo "Example: $0 2024-07-15 my_backup_name"
    exit 1
fi

# Cleanup previous restore directory
rm -rf $RESTORE_DIR

# Download and extract the full backup
download_and_extract_backup "${BACKUP_NAME}_full_backup_${DATE}.xbstream.zst" $RESTORE_DIR

# Apply the full backup
apply_backup $RESTORE_DIR

# Check for and apply incremental backups
incremental_backup_found=false
for i in {1..6}; do
    incremental_backup="${BACKUP_NAME}_inc_backup_${DATE}-${i}.xbstream.zst"
    if aws s3 ls s3://$S3_BUCKET/$incremental_backup > /dev/null 2>&1; then
        incremental_backup_found=true
        download_and_extract_backup $incremental_backup $RESTORE_DIR
        apply_backup $RESTORE_DIR
    else
        echo "No more incremental backups found."
        break
    fi
done

if [[ "$incremental_backup_found" = true ]]; then
    # Final prepare step
    echo "Finalizing the backup..."
    xtrabackup --prepare --target-dir=$RESTORE_DIR
fi

# Stop MySQL service
echo "Stopping MySQL service..."
systemctl stop mysql

# Move the backup to the MySQL data directory
move_backup $RESTORE_DIR

# Start MySQL service
echo "Starting MySQL service..."
systemctl start mysql

echo "Restore completed successfully."
