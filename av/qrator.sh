#!/usr/bin/env bash

# use
# bash <(curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/qrator.sh)

# open ports only for qrator upstream servers
firewall-cmd --new-zone=qrator --permanent 
firewall-cmd --reload
firewall-cmd --permanent --zone=qrator --add-port=80/tcp 
firewall-cmd --permanent --zone=qrator --add-port=443/tcp 
firewall-cmd --permanent --zone=qrator --add-source=87.245.197.192
firewall-cmd --permanent --zone=qrator --add-source=87.245.197.193
firewall-cmd --permanent --zone=qrator --add-source=87.245.197.194
firewall-cmd --permanent --zone=qrator --add-source=87.245.197.195
firewall-cmd --permanent --zone=qrator --add-source=83.234.15.112
firewall-cmd --permanent --zone=qrator --add-source=83.234.15.113
firewall-cmd --permanent --zone=qrator --add-source=83.234.15.114
firewall-cmd --permanent --zone=qrator --add-source=83.234.15.115
firewall-cmd --permanent --zone=qrator --add-source=66.110.32.128
firewall-cmd --permanent --zone=qrator --add-source=66.110.32.129
firewall-cmd --permanent --zone=qrator --add-source=66.110.32.130
firewall-cmd --permanent --zone=qrator --add-source=66.110.32.131
firewall-cmd --permanent --zone=qrator --add-source=185.94.108.0/24
firewall-cmd --reload
firewall-cmd --zone=public --remove-port=443/tcp --permanent
firewall-cmd --zone=public --remove-port=80/tcp --permanent
firewall-cmd --reload

# if zabbix
# firewall-cmd --zone=special --remove-source=ip_zabbix_server --permanent                                                                                                                                         
# firewall-cmd --zone=special --remove-port=10050/tcp --permanent
# firewall-cmd --reload
# firewall-cmd --permanent --zone=qrator --add-source=ip_zabbix_server
# firewall-cmd --permanent --zone=qrator --add-port=10050/tcp
# firewall-cmd --reload
