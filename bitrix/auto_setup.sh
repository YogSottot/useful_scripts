#!/bin/sh

# use
# curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/auto_setup.sh | bash -s -- /home/bitrix/www

mkdir -p /opt/backup/db && cd /opt/backup/
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/backup-db.php &&
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/backup_bitrixdb_native.sh &&
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/backup_upload.sh &&
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/restore_upload.sh &&
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/backup_bitrix_files.sh &&
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/test.php &&
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/percona-db.sh &&
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/percona-db-stream.sh &&
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/percona-restore-stream.sh &&
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/percona-restore.sh &&
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/percona-restore-single-db.sh &&
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/percona-restore-single-db-5.6.sh &&

chmod +x *.sh
yum -y install http://www.percona.com/downloads/percona-release/redhat/0.1-4/percona-release-0.1-4.noarch.rpm
yum -y install https://dev.mysql.com/get/Downloads/Connector-Python/mysql-connector-python-2.1.7-1.el7.x86_64.rpm
yum -y install https://dev.mysql.com/get/Downloads/MySQLGUITools/mysql-utilities-1.6.5-1.el7.noarch.rpm
yum -y install python-pip percona-xtrabackup-24 qpress pv
pip install python-swiftclient --user

# for restore upload directly from bitrix
sudo -i -u bitrix bash << EOF
pip install python-swiftclient --user
EOF
crontab -l | { cat; echo "30 */3 * * * /opt/backup/backup_bitrixdb_native.sh $1 > /dev/null 2>&1 || true" ; } | crontab -
#crontab -l | { cat; echo "00 01 * * * /opt/backup/backup_upload.sh $1 > /dev/null 2>&1 || true"; } | crontab -
crontab -l | { cat; echo "#20 */3 * * * /opt/backup/percona-db-stream.sh $1 $2 > /dev/null 2>&1 || true"; } | crontab -

curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/rclone.sh | bash -s -- $1
