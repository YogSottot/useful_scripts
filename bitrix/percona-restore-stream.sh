#!/bin/sh

backup_dir=$1
backup_name=$2
if [ -z ${backup_dir} ]; then
	echo Usage: $0 /dir/with/backup [backup_name]
	exit
fi

mv /root/.my.cnf /root/.my.cnf.old
cp ${backup_dir}/.my.cnf /root/
if [ -d /var/lib/zabbix/ ] ; then cp -f ${backup_dir}/.my.cnf /var/lib/zabbix/ ; fi

rm -rf ${backup_dir}/perconatmp
mkdir ${backup_dir}/perconatmp
xbstream -x < ${backup_name} -C ${backup_dir}/perconatmp
xtrabackup --decompress --remove-original --target-dir=${backup_dir}/perconatmp
xtrabackup --prepare --target-dir=${backup_dir}/perconatmp

systemctl stop mysql
mv /var/lib/mysql /var/lib/mysql.old

xtrabackup --move-back --target-dir=${backup_dir}/perconatmp
chown -R mysql:mysql /var/lib/mysql

systemctl start mysql

rm -rf ${backup_dir}/perconatmp

# zabbix
if [ -d /var/lib/zabbix/ ] ; then
    echo;echo "Don not forget to edit /var/lib/zabbix/percona/scripts/ss_get_mysql_stats.php.cnf,"
    echo;exit
fi