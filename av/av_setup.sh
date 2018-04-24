#!/bin/sh

# use
# curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/av_setup.sh | bash -s -- your_mail

if [ ! -d /opt/av/abh/reports/ ] ; then mkdir -p /opt/av/abh/reports/; fi
cd /opt/av/

#secure from other users
chmod 700 /opt/av/

yum install postfix clamav clamav-update rkhunter fail2ban inotify-tools unhide mailx -y

# NOT TO DO maldet
# https://github.com/crylium/clamav-daily/blob/master/clamscan-daily-script.sh

# send report
systemctl enable postfix && systemctl restart postfix

# generate db
rkhunter --propupd

# bitrix av
echo ';auto_prepend_file = /home/bitrix/www/bitrix/modules/security/tools/start.php' >> /etc/php.d/z_bx_custom.ini

mail=$1
find /etc/sysconfig/rkhunter -type f -print0 | xargs -0 sed -i 's/MAILTO\=root\@localhost/MAILTO\='${mail}'/g'
echo 'ALLOWHIDDENDIR=/etc/.hg' >> /etc/rkhunter.conf.local
echo 'ALLOWHIDDENFILE=/etc/.hgignore' >> /etc/rkhunter.conf.local
# ab
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/update.abh.sh
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/abh.sh
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/manual.av.check.sh
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/av_scripts_update.sh
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/.adirignore_usr
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/.aurlignore_usr
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/.aignore_usr
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/.adirignore
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/.aurlignore
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/.aignore
chmod +x *.sh

# initial av install
/opt/av/update.abh.sh > /dev/null 2>&1

# update cron
crontab -l | { cat; echo "0 1 * * 4 /opt/av/update.abh.sh > /dev/null 2>&1 || true" ; } | crontab -
crontab -l | { cat; echo "5 0 * * * /opt/av/av_scripts_update.sh > /dev/null 2>&1 || true"; } | crontab -
crontab -l | { cat; echo "10 1 * * * /opt/av/abh.sh ${mail} > /dev/null 2>&1 || true"; } | crontab -

# hide process from all besides zabbix
# Only after zabbix install
if [ -d /etc/zabbix/ ];then

    echo 'proc /proc proc defaults,hidepid=2,gid=zabbix 0 0' >> /etc/fstab
    mount -o remount,defaults,hidepid=2,gid=zabbix /proc

else

    echo 'proc /proc proc defaults,hidepid=2 0 0' >> /etc/fstab
    mount -o remount,defaults,hidepid=2 /proc

fi

# block some bots
curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/botblock.sh | bash
