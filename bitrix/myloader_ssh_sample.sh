#!/bin/sh
# https://github.com/mydumper/mydumper/releases
# yum install libzstd -y 

database="$1"
mail="$2"

ssh sem "/opt/backup/mydumper_bitrixdb_sample.sh /home/bitrix/www/ ${mail}"
/opt/backup/myloader_bitrixdb_sample.sh ${database} ${mail}
mysql --execute="update ${database}.b_option set VALUE='0' where NAME='dump_auto_enable_auto';"
