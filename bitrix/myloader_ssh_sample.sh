#!/bin/sh
# https://github.com/mydumper/mydumper/releases
# yum install libzstd -y 

database="$1"
mail="$2"

ssh sem "/opt/backup/mydumper_bitrixdb_sample.sh /home/bitrix/www/ ${mail}"
/opt/backup/myloader_bitrixdb_sample.sh ${database} ${mail}
# disable auto backup
mysql --execute="update ${database}.b_option set VALUE='0' where NAME='dump_auto_enable_auto';"
# change domain in main module
mysql --execute="update ${database}.b_option set VALUE='dev.example.tld' where MODULE_ID='main' and NAME='server_name';"
# set установка для разработки
mysql --execute="update ${database}.b_option set VALUE='Y' where MODULE_ID='main' and NAME='update_devsrv';"
# URL сервера (без http://): для сайта s1
mysql --execute="update ${database}.b_lang set SERVER_NAME='dev.example.tld' where LID='s1';"
# удаление старых доменных имён
mysql --execute="DELETE FROM ${database}.b_lang_domain WHERE LID='s1';"
# Доменное имя: (список доменных имен, каждое в новой строке) для сайта s1 / s2 / s3
mysql --execute="INSERT INTO ${database}.b_lang_domain (LID, domain) VALUES ('s1','dev.example.tld'),('s1','dev2.example.tld'),('s2','dev3.example.tld'),('s2','dev4.example.tld'),('s3','dev5.example.tld'),('s3','dev2.example.org');"

# mysql --execute="select * from sitemanager.b_lang"
# mysql --execute="select * from sitemanager.b_lang_domain"


