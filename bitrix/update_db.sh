#!/usr/bin/env bash

database="$1"

printf "Start update db settings\n"
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

# отключение pull/push-сервера
mysql --execute="UPDATE ${database}.b_option SET VALUE='N' WHERE b_option.MODULE_ID='pull' AND b_option.NAME='nginx';"
mysql --execute="UPDATE ${database}.b_option SET VALUE='N' WHERE b_option.MODULE_ID='pull' AND b_option.NAME='push';"
# set pull-server on server
mysql --execute="UPDATE ${database}.b_option SET VALUE='personal' WHERE b_option.MODULE_ID='pull' AND b_option.NAME='server_mode';"
mysql --execute="UPDATE ${database}.b_option SET VALUE='BRfYy36Yjct' WHERE b_option.MODULE_ID='pull' AND b_option.NAME='signature_key';"

# mysql --execute="select * from sitemanager.b_lang"
# mysql --execute="select * from sitemanager.b_lang_domain"


