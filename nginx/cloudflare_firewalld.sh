#!/usr/bin/env bash

# use
# wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/nginx/cloudflare_firewalld.sh -N -P /opt/backup/
source=`cat $1`
# open ports only for qrator upstream servers
firewall-cmd --new-zone=cloudflare --permanent
firewall-cmd --reload
firewall-cmd --permanent --zone=cloudflare --add-service=http
firewall-cmd --permanent --zone=cloudflare --add-service=https

# remove all sources first
for i in $(firewall-cmd --zone=cloudflare --list-sources); do
        echo "removing '$i'"
        firewall-cmd --zone=cloudflare --permanent --remove-source=${i};
done

# adding ip
# for i in $(curl "https://www.cloudflare.com/ips-v4"); do
# for i in $(curl "https://www.cloudflare.com/ips-v6"); do
for i in ${source}; do
        echo "adding '$i'"
        firewall-cmd --zone=cloudflare --permanent --add-source=${i};
done


echo "reloading..."
firewall-cmd --reload
firewall-cmd --zone=public --remove-port=443/tcp --permanent
firewall-cmd --zone=public --remove-port=80/tcp --permanent
firewall-cmd --zone=public --remove-service=http --permanent
firewall-cmd --zone=public --remove-service=https --permanent
firewall-cmd --reload

# if zabbix
# firewall-cmd --zone=special --remove-source=ip_zabbix_server --permanent
# firewall-cmd --zone=special --remove-port=10050/tcp --permanent
# firewall-cmd --reload
# firewall-cmd --permanent --zone=qrator --add-source=ip_zabbix_server
# firewall-cmd --permanent --zone=qrator --add-port=10050/tcp
# firewall-cmd --reload

# revert
# firewall-cmd --zone=public --add-service=https --permanent && firewall-cmd --zone=public --add-service=http --permanent && firewall-cmd --reload
