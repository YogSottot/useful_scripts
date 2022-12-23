#!/usr/bin/env bash
set -eo pipefail
# use
# curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/zabbix.sh | bash -s -- ip server hostname
ip=$1
server=$2
hostname=$3


# open ports only for zabbix server
firewall-cmd --new-zone=special --permanent && firewall-cmd --reload
firewall-cmd --permanent --zone=special --add-source=${ip} && firewall-cmd --reload
firewall-cmd --permanent --zone=special --add-port=10050/tcp && firewall-cmd --reload

# install agent
yum -y install https://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-2.el7.noarch.rpm
yum -y install zabbix-agent


cat <<EOT >> /etc/zabbix/zabbix_agentd.d/99-override.conf
EnableRemoteCommands=1
LogRemoteCommands=1
Server=${server},${ip}
StartAgents=3
ServerActive=${server},${ip}
Hostname=${hostname}
Timeout=30
EOT

systemctl enable zabbix-agent
systemctl start zabbix-agent

#if  yum info Percona-Server-server-* | egrep -q installed  ; then

#yum install percona-zabbix-templates -y

#cp /var/lib/zabbix/percona/templates/userparameter_percona_mysql.conf  /etc/zabbix/zabbix_agentd.d/

#service zabbix-agent restart

#dbuser=`grep user /root/.my.cnf | cut -d = -f2`
#dbpassword=`grep password /root/.my.cnf | cut -d = -f2`
# Remove surrounding quotes only if there are surrounding quotes.
#dbpassword="${dbpassword%\'}"
#dbpassword="${dbpassword#\'}"

#cat <<EOT >> /var/lib/zabbix/percona/scripts/ss_get_mysql_stats.php.cnf
#<?php
#\$mysql_user = '${dbuser}';
#\$mysql_pass = '${dbpassword}';
#EOT

# Тестируем скрипт
# /var/lib/zabbix/percona/scripts/get_mysql_stats_wrapper.sh gg
#3159212
# Аналогично
# /usr/bin/php -q /var/lib/zabbix/percona/scripts/ss_get_mysql_stats.php --host localhost --items gg

mkdir -p /var/lib/zabbix/
cp /root/.my.cnf /var/lib/zabbix/

#Проверяем под пользователем zabbix
# sudo -u zabbix -H /var/lib/zabbix/percona/scripts/get_mysql_stats_wrapper.sh running-slave
# 0
# Должен вернуть 0 или 1, но не “Access denied”

#Выставим корректного владельца и права

chown -R zabbix:zabbix /var/lib/zabbix/
chmod 640 /var/lib/zabbix/.my.cnf
#chmod 640 /var/lib/zabbix/percona/scripts/ss_get_mysql_stats.php.cnf
#chmod 664 /tmp/localhost-mysql_cacti_stats.txt
#chown zabbix:zabbix /tmp/localhost-mysql_cacti_stats.txt ;
service zabbix-agent restart
#fi
