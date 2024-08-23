#!/bin/bash

# Configuration
SWIFT_CONTAINER="your_container"
RESTORE_DIR="/tmp/mysql_restore"
MYSQL_DATA_DIR="/var/lib/mysql"
DATE=$1

# Functions
download_and_extract_backup() {
    local backup_name=$1
    local target_dir=$2
    echo "Downloading and extracting $backup_name..."
    mkdir -p $target_dir
    xbcloud get --storage=swift $SWIFT_CONTAINER/$backup_name | xbstream -x -C $target_dir
}

apply_backup() {
    local target_dir=$1
    echo "Applying backup from $target_dir..."
    xtrabackup --prepare --apply-log-only --target-dir=$target_dir
}

copy_backup() {
    local target_dir=$1
    echo "Copying backup to MySQL data directory..."
    xtrabackup --copy-back --target-dir=$target_dir
    chown -R mysql:mysql $MYSQL_DATA_DIR
}

# Main script
if [[ -z "$DATE" ]]; then
    echo "Usage: $0 <date>"
    echo "Example: $0 2024-07-15"
    exit 1
fi

# Download and extract the full backup
download_and_extract_backup "full_backup_$DATE" $RESTORE_DIR

# Apply the full backup
apply_backup $RESTORE_DIR

# Check for and apply incremental backups
incremental_backup_found=false
for i in {1..6}; do
    incremental_backup="inc_backup_$DATE"
    if swift stat $SWIFT_CONTAINER $incremental_backup > /dev/null 2>&1; then
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

# Copy the backup to the MySQL data directory
copy_backup $RESTORE_DIR

# Start MySQL service
echo "Starting MySQL service..."
systemctl start mysql

echo "Restore completed successfully."
