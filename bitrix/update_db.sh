#!/usr/bin/env bash
set -eo pipefail

doc_root="$1"
dev_domain="$2"

if [ -z ${doc_root} ] || [ -z ${dev_domain} ]; then
	echo Usage: $0 /path/to/document/root dev_domain.tld
	exit 1
fi

settings=${doc_root}/bitrix/.settings.php

readcfg() {
        grep -m 1 $1 ${settings} | sed "s/.*' => '\(.*\)',.*/\1/"
}

host=`readcfg host`
username=`readcfg login`
password=`readcfg password`
database=`readcfg database`

printf "Start update db settings for: ${database}\n"
# disable auto backup
mysql --execute="update ${database}.b_option set VALUE='0' where NAME='dump_auto_enable_auto';"
# set установка для разработки
mysql --execute="update ${database}.b_option set VALUE='Y' where MODULE_ID='main' and NAME='update_devsrv';"
# отключить хранение сессий в бд
mysql --execute="UPDATE ${database}.b_option SET VALUE='N' WHERE b_option.MODULE_ID='security' AND b_option.NAME='session';"
# отключить TOTP
mysql --execute="UPDATE ${database}.b_option SET VALUE='N' WHERE b_option.MODULE_ID='security' AND b_option.NAME='otp_enabled';"
mysql --execute="UPDATE ${database}.b_option SET VALUE='N' WHERE b_option.MODULE_ID='security' AND b_option.NAME='otp_mandatory_using';"

# удаление старых доменных имён
mysql --execute="DELETE FROM ${database}.b_lang_domain;"
# удаление путей к сайтам
mysql --execute="UPDATE ${database}.b_lang SET DOC_ROOT = NULL WHERE DOC_ROOT is not null;"

# изменение политики безопасности, чтобы не разлогинивало.
mysql --execute="UPDATE ${database}.b_group SET SECURITY_POLICY='a:12:{s:15:"SESSION_TIMEOUT";s:4:"3600";s:15:"SESSION_IP_MASK";s:7:"0.0.0.0";s:13:"MAX_STORE_NUM";s:3:"100";s:13:"STORE_IP_MASK";s:7:"0.0.0.0";s:13:"STORE_TIMEOUT";s:4:"4320";s:17:"CHECKWORD_TIMEOUT";s:2:"60";s:15:"PASSWORD_LENGTH";s:2:"10";s:18:"PASSWORD_UPPERCASE";s:1:"Y";s:18:"PASSWORD_LOWERCASE";s:1:"Y";s:15:"PASSWORD_DIGITS";s:1:"Y";s:20:"PASSWORD_PUNCTUATION";s:1:"Y";s:14:"LOGIN_ATTEMPTS";s:1:"3";}	' WHERE b_group.ID='1';"

#if [ ${doc_root} == /home/bitrix/ext_www/dev.example.tld ]; then
    # change domain in main module
    mysql --execute="update ${database}.b_option set VALUE='${dev_domain}' where MODULE_ID='main' and NAME='server_name';"
    # URL сервера (без http://): для сайта s1
    mysql --execute="update ${database}.b_lang set SERVER_NAME='${dev_domain}' where LID='s1';"

    # Доменное имя: (список доменных имен, каждое в новой строке) для сайта s1 / s2 / s3
    # mysql --execute="INSERT INTO ${database}.b_lang_domain (LID, domain) VALUES ('s1','dev.example.tld'),('s1','dev2.example.tld'),('s2','dev3.example.tld'),('s2','dev4.example.tld'),('s3','dev5.example.tld'),('s3','dev2.example.org');"
#fi

# mysql --execute="select * from sitemanager.b_lang"
# mysql --execute="select * from sitemanager.b_lang_domain"

# отключение pull/push-сервера
#mysql --execute="UPDATE ${database}.b_option SET VALUE='N' WHERE b_option.MODULE_ID='pull' AND b_option.NAME='nginx';"
#mysql --execute="UPDATE ${database}.b_option SET VALUE='N' WHERE b_option.MODULE_ID='pull' AND b_option.NAME='push';"
# set pull-server on server
#mysql --execute="UPDATE ${database}.b_option SET VALUE='personal' WHERE b_option.MODULE_ID='pull' AND b_option.NAME='server_mode';"
#mysql --execute="UPDATE ${database}.b_option SET VALUE='BRfYy36Yjct' WHERE b_option.MODULE_ID='pull' AND b_option.NAME='signature_key';"
#mysql --execute="UPDATE ${database}.b_option SET VALUE='http://dev.example.org:8895/bitrix/pub/' WHERE b_option.MODULE_ID='pull' AND b_option.NAME='path_to_publish ';"

# смена почты
#mysql --execute="update sitemanager.b_option set VALUE='test@domain.tld' where MODULE_ID='main' and NAME='all_bcc';"
#mysql --execute="update sitemanager.b_option set VALUE='test@domain.tld' where MODULE_ID='main' and NAME='email_from';"
#mysql --execute="update sitemanager.b_option set VALUE='test@domain.tld' where MODULE_ID='sale' and NAME='order_email';"

#mysql --execute="update sitemanager.b_lang set EMAIL='test@domain.tld' where LID='s1';"
#mysql --execute="update sitemanager.b_lang set EMAIL='test@domain.tld' where LID='s2';"

# Доступ к публичной части закрыт
# mysql --execute="UPDATE ${database}.b_option SET VALUE='Y' WHERE b_option.MODULE_ID='main' AND b_option.NAME='site_stopped';"
