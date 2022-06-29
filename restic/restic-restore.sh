#!/usr/bin/env bash
set -eo pipefail

rc_dir="/opt/backup/restic/rc.files"
rc_file="$1"
target="$2"

# run under bitrix user
chmod 755 /opt/backup/
# example /opt/backup/restic/restic-wrapper.sh www root@localhost restore latest --target /home/bitrix/ --exclude www/upload
sudo -i -u bitrix bash << EOF
# source rc files
source "$rc_dir/$rc_file.rc"
# this will restore to /home/bitrix/www first step without upload
/usr/local/bin/restic restore latest --target ${target} --exclude www/upload > /tmp/restic_log_restore_main 2>&1

# second step upload
/usr/local/bin/restic restore latest --target ${target} --include www/upload > /tmp/restic_log_restore_upload 2>&1
EOF
chmod 700 /opt/backup/
