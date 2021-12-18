#!/bin/sh
set -e
# use
# curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/auto_setup.sh | bash -s -- /home/bitrix/www

mkdir -p /opt/backup/db 
cd /opt/backup/
chmod 700 /opt/backup/
#wget -N https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/backup-db.php
#wget -N https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/backup_bitrixdb_native.sh
wget -N https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/backup_bitrixdb_hourly.sh
wget -N https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/backup_bitrixdb_daily.sh
#wget -N https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/rclone.sh
#wget -N https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/rclone_restore_upload.sh
#wget -N https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/backup_bitrix_files.sh
wget -N https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/backup_configs.sh
#wget -N https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/test.php
wget -N https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/percona-db.sh
wget -N https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/percona-db-stream.sh
wget -N https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/percona-restore-stream.sh
wget -N https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/percona-restore.sh
wget -N https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/percona-restore-single-db.sh
wget -N https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/percona-db-inc.sh
wget -N https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/backup_percona_inc_hourly.sh
wget -N https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/backup_percona_full_daily.sh
wget -N https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/percona-restore-inc.sh
wget -N https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/config.ini
wget -N https://raw.githubusercontent.com/YogSottot/useful_scripts/master/fail2ban/firewalld-asn.sh

chmod +x *.sh
#yum -y install https://dev.mysql.com/get/Downloads/Connector-Python/mysql-connector-python-2.1.7-1.el7.x86_64.rpm
#yum -y install https://dev.mysql.com/get/Downloads/MySQLGUITools/mysql-utilities-1.6.5-1.el7.noarch.rpm
yum -y install python-pip percona-xtrabackup-24 qpress pv percona-toolkit mailx
pip install python-swiftclient --user

# for restore upload directly from bitrix
#sudo -i -u bitrix bash << EOF
#pip install python-swiftclient --user
#EOF
#crontab -l | { cat; echo "30 */3 * * * /opt/backup/backup_bitrixdb_native.sh $1 > /dev/null 2>&1 || true" ; } | crontab -
#crontab -l | { cat; echo "#20 */3 * * * /opt/backup/percona-db-stream.sh $1 $2 > /dev/null 2>&1 || true"; } | crontab -
crontab -l | { cat; echo "05 0 * * * /opt/backup/backup_configs.sh $1 > /dev/null 2>&1 || true"; } | crontab -
#crontab -l | { cat; echo "10 1 * * * /opt/backup/backup_bitrix_files.sh $1 > /dev/null 2>&1 || true"; } | crontab -
crontab -l | { cat; echo "15 1 * * * /opt/backup/backup_bitrixdb_daily.sh $1 > /dev/null 2>&1 || true"; } | crontab -
#crontab -l | { cat; echo "40 */3 * * * /opt/backup/backup_bitrixdb_hourly.sh $1 > /dev/null 2>&1 || true"; } | crontab -

#curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/rclone.sh | bash -s -- $1
