#!/usr/bin/env bash
set -eu
# use curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/isp/import_vm_bitrix.sh | bash -s -- old_ip new_ip
# после импорта нужно поменять старый ip на новый не только в /etc/sysconfig/network-scripts/ifcfg-eth0
old_ip=$1
new_ip=$2

find /opt/webdir/ -type f -print0 | xargs -0 sed -i "s/${old_ip}/${new_ip}/g"
find /etc/ansible/ -type f -print0 | xargs -0 sed -i "s/${old_ip}/${new_ip}/g"
find /etc/hosts -type f -print0 | xargs -0 sed -i "s/${old_ip}/${new_ip}/g"
find /etc/munin/ -type f -print0 | xargs -0 sed -i "s/${old_ip}/${new_ip}/g"
