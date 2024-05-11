#!/usr/bin/env bash
set -eo pipefail

mail=$1
# use
# curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/imunifyav/iav_setup.sh | bash -s -- your_mail

# https://docs.imunifyav.com/cli/

if [ -z "${mail}" ]; then
	echo Usage: "$0" your_mail
	exit
fi

yum install -y mailx jq oniguruma

if [ ! -d /etc/sysconfig/imunify360/ ] ; then
mkdir -p /etc/sysconfig/imunify360/
echo -e '[paths]\nui_path = /opt/iav/.imunifyav\n\n[integration_scripts]\nusers = /opt/iav/get-users.sh\ndomains = /opt/iav/get-domains.sh\n' >> /etc/sysconfig/imunify360/integration.conf ; fi

mkdir -p /opt/iav/.imunifyav
ln -s /opt/iav/.imunifyav /home/bitrix/www/

wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/imunifyav/iav_hook.sh -N -P /opt/iav/
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/imunifyav/get-users.sh -N -P /opt/iav/
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/imunifyav/get-domains.sh -N -P /opt/iav/
chmod +x  /opt/iav/*.sh
sed -i "s/your_mail/${mail}/g" /opt/iav/iav_hook.sh


wget https://repo.imunify360.cloudlinux.com/defence360/imav-deploy.sh
bash imav-deploy.sh
rm -f imav-deploy.sh

chown root:_imunify -R /opt/iav/

# got to Notifications and setup script with mail as argument
imunify-antivirus notifications-config update '{"rules": {"USER_SCAN_MALWARE_FOUND": {"SCRIPT": {"scripts": ["/opt/iav/iav_hook.sh"], "enabled": true}}}}'
imunify-antivirus notifications-config update '{"rules": {"CUSTOM_SCAN_MALWARE_FOUND": {"SCRIPT": {"scripts": ["/opt/iav/iav_hook.sh"], "enabled": true}}}}'

# ignore list
imunify-antivirus malware ignore add /home/bitrix/www/bitrix/cache/
imunify-antivirus malware ignore add /home/bitrix/www/bitrix/backup/
imunify-antivirus malware ignore add /home/bitrix/www/bitrix/managed_cache/
imunify-antivirus malware ignore add /home/bitrix/www/bitrix/stack_cache/
imunify-antivirus malware ignore add /home/bitrix/www/bitrix/html_pages/
imunify-antivirus malware ignore add /home/bitrix/www/upload/
imunify-antivirus malware ignore add /home/bitrix/.cache/
imunify-antivirus malware ignore add /home/bitrix/.bx_temp/
#imunify-antivirus malware ignore add "/home/bitrix/ext_www/(.*)/bitrix/backup/(.*)"
#imunify-antivirus malware ignore add "/home/bitrix/ext_www/(.*)/bitrix/cache/(.*)"
#imunify-antivirus malware ignore add "/home/bitrix/ext_www/(.*)/bitrix/managed_cache/(.*)"
#imunify-antivirus malware ignore add "/home/bitrix/ext_www/(.*)/bitrix/stack_cache/(.*)"
#imunify-antivirus malware ignore add "/home/bitrix/ext_www/(.*)/bitrix/html_pages/(.*)"
#imunify-antivirus malware ignore add "/home/bitrix/ext_www/(.*)/upload/(.*)"

cat <<\EOT >> /etc/sysconfig/imunify360/malware-filters-admin-conf/ignored.txt
^/home/bitrix/ext_www/(.*)/bitrix/backup/(.*)
^/home/bitrix/ext_www/(.*)/bitrix/cache/(.*)
^/home/bitrix/ext_www/(.*)/bitrix/managed_cache/(.*)
^/home/bitrix/ext_www/(.*)/bitrix/stack_cache/(.*)
^/home/bitrix/ext_www/(.*)/bitrix/html_pages/(.*)
^/home/bitrix/ext_www/(.*)/upload/(.*)
EOT

# add admin user
echo _imunify >> /etc/sysconfig/imunify360/auth.admin

# we need imunify-antivirus >=5.5.7 for  next command, so
# temp fix, to remove later
# yum -y update imunify-antivirus --enablerepo="imunify360-rollout-*-bypass"

imunify360-agent malware rebuild patterns


# https://docs.imunifyav.com/config_file_description/
imunify-antivirus config update '{"MALWARE_SCANNING": {"hyperscan": true}}'
# ionice
imunify-antivirus config update '{"MALWARE_SCAN_INTENSITY": {"cpu": 2}}'
imunify-antivirus config update '{"MALWARE_SCAN_INTENSITY": {"io": 2}}'
imunify-antivirus config update '{"MALWARE_SCAN_INTENSITY": {"ram": 1024}}'
imunify-antivirus config update '{"MALWARE_SCAN_INTENSITY": {"user_scan_cpu": 2}}'
imunify-antivirus config update '{"MALWARE_SCAN_INTENSITY": {"user_scan_io": 2}}'
imunify-antivirus config update '{"MALWARE_SCAN_INTENSITY": {"user_scan_ram": 1024}}'

imunify-antivirus config update '{"RESOURCE_MANAGEMENT": {"cpu_limit": 1}}'
imunify-antivirus config update '{"RESOURCE_MANAGEMENT": {"io_limit": 1}}'
imunify-antivirus config update '{"RESOURCE_MANAGEMENT": {"ram_limit": 500}}'

# cron
#imunify-antivirus config update '{"MALWARE_SCAN_SCHEDULE": {"day_of_month": 1}}'
#imunify-antivirus config update '{"MALWARE_SCAN_SCHEDULE": {"hour": 3}}'
imunify-antivirus config update '{"MALWARE_SCAN_SCHEDULE": {"interval": "none"}}'
#imunify-antivirus config update '{"PERMISSIONS": {"allow_malware_scan": true}}'

# shedule
cat <<\EOT >> /etc/cron.d/iav_scan_schedule
10 1 * * * root /usr/bin/imunify-antivirus update sigs >/dev/null 2>&1 && /usr/bin/imunify-antivirus malware on-demand start --path='/home/bitrix/' --ignore-mask='/home/bitrix/.bx_temp/*,/home/bitrix/.cache/*,/home/bitrix/www/bitrix/backup/*,/home/bitrix/www/bitrix/cache/*,/home/bitrix/www/bitrix/managed_cache/*,/home/bitrix/www/bitrix/stack_cache/*,/home/bitrix/www/bitrix/html_pages/*,/home/bitrix/www/upload/*,/home/bitrix/ext_www/*/bitrix/backup/*,/home/bitrix/ext_www/*/bitrix/cache/*,/home/bitrix/ext_www/*/bitrix/managed_cache/*,/home/bitrix/ext_www/*/bitrix/stack_cache/*,/home/bitrix/ext_www/*/bitrix/html_pages/*,/home/bitrix/ext_www/*/upload/*' --file-mask="*.php,*.js,*.html,*htaccess" --no-follow-symlinks --intensity-cpu 3 --intensity-io 3 >/dev/null 2>&1
EOT

# 10 1 * * * root /usr/bin/imunify-antivirus update sigs >/dev/null 2>&1 ; /usr/bin/systemctl restart imunify-antivirus.service >/dev/null 2>&1 && /usr/bin/imunify360-agent malware user scan --background >/dev/null 2>&1

#systemctl stop aibolit-resident.service

#systemctl stop imunify-notifier.service

#systemctl disable aibolit-resident.service
#systemctl disable imunify-antivirus.service
#systemctl disable imunify-notifier.service

#systemctl disable aibolit-resident.socket
#systemctl disable imunify-antivirus-sensor.socket
#systemctl disable imunify-antivirus-user.socket
#systemctl disable imunify-antivirus.socket
#systemctl disable imunify-notifier.socket

#systemctl stop aibolit-resident.socket

#systemctl stop imunify-antivirus-sensor.socket
#systemctl stop imunify-antivirus-user.socket
#systemctl stop imunify-antivirus.socket
#systemctl stop imunify-notifier.socket
#systemctl stop imunify-antivirus.service

# костыли костылики
#sed -i '/skip-system-owner/d' /opt/alt/python38/lib/python3.8/site-packages/defence360agent/malwarelib/scan/ai_bolit.py
#rm -rf /opt/alt/python38/lib/python3.8/site-packages/defence360agent/malwarelib/scan/__pycache__/*
#systemctl restart imunify-antivirus.service

# or you can edit /etc/login.defs set min uid/gid 600 and max system to 599
sed -i "s/UID_MIN                  1000/UID_MIN                  600/g" /etc/login.defs
sed -i "s/SYS_UID_MAX               999/SYS_UID_MAX               599/g" /etc/login.defs
sed -i "s/GID_MIN                  1000/GID_MIN                  600/g" /etc/login.defs
sed -i "s/SYS_GID_MAX               999/SYS_GID_MAX               599/g" /etc/login.defs

# mail
# imunify-antivirus config update '{"ADMIN_CONTACTS": {"emails": ["${mail}",]}'
# imunify-antivirus notifications-config update '{"admin": {"default_emails": ["${mail}"]}}'

# manual scan
# imunify-antivirus update sigs
# imunify-antivirus malware on-demand start --path='/home/bitrix/www' --ignore-mask='/home/bitrix/www/bitrix/backup/*,/home/bitrix/www/bitrix/cache/*,/home/bitrix/www/bitrix/managed_cache/*,/home/bitrix/www/bitrix/stack_cache/*,/home/bitrix/www/bitrix/html_pages/*,/home/bitrix/www/upload/*' --file-mask="*.php,*.js,*.html,.htaccess" --no-follow-symlinks --intensity-cpu 3 --intensity-io 3

# /usr/bin/imunify-antivirus malware on-demand start --path='/home/bitrix/' --ignore-mask='/home/bitrix/.bx_temp/*,/home/bitrix/.cache/*,/home/bitrix/www/bitrix/backup/*,/home/bitrix/www/bitrix/cache/*,/home/bitrix/www/bitrix/managed_cache/*,/home/bitrix/www/bitrix/stack_cache/*,/home/bitrix/www/bitrix/html_pages/*,/home/bitrix/www/upload/*,/home/bitrix/ext_www/*/bitrix/backup/*,/home/bitrix/ext_www/*/bitrix/cache/*,/home/bitrix/ext_www/*/bitrix/managed_cache/*,/home/bitrix/ext_www/*/bitrix/stack_cache/*,/home/bitrix/ext_www/*/bitrix/html_pages/*,/home/bitrix/ext_www/*/upload/*' --file-mask="*.php,*.js,*.html,.htaccess" --no-follow-symlinks --intensity-cpu 3 --intensity-io 3

# imunify-antivirus malware on-demand list

# /usr/bin/imunify360-agent malware user scan

# imunify-antivirus submit false-positive --reason REASON <file>
# imunify-antivirus submit false-negative <file>
# /opt/alt/php-internal/usr/bin/php -c /opt/alt/php-internal/etc/php.d.all/posix.ini /opt/ai-bolit/ai-bolit.php --smart --deobfuscate --avdb /var/imunify360/files/sigs/v1/aibolit/ai-bolit-hoster-full.db --memory=1024M --hs /var/imunify360/files/sigs/v1/aibolit/hyperscan --ignore-quarantine  --use-template-in-path --with-suspicious --size=0 --mode=2  --path=/home/bitrix/ --report=/home/bitrix/www/bitrix/backup/report_2024.05.11.html

# https://cloudlinux.zendesk.com/hc/en-us/articles/360014490279--Imunify-agent-is-not-running-troubleshooting
# https://firstvds.ru/technology/site-viruses-removal-checklist
