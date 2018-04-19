#!/usr/bin/env bash

# use
# curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/initial_server_setup/initial_setup.sh | bash

# install useful programms
yum -y install --enablerepo=epel ncdu iotop htop bind-utils traceroute mc bash-completion bash-completion-extras yum-utils nano tmux deltarpm

# install liquidprompt
cd /opt/ && git clone https://github.com/nojhan/liquidprompt
chown root:bitrix -R /opt/liquidprompt
echo -e "alias mc='mc -x'\n[[ \$- = *i* ]] && source /opt/liquidprompt/liquidprompt" >> ~/.bashrc
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/initial_server_setup/liquidpromptrc -O ~/.config/liquidpromptrc
source /opt/liquidprompt/liquidprompt

sudo -i -u bitrix bash << EOF
mkdir ~/.config
echo -e "alias mc='mc -x'" >> ~/.bashrc
echo -e '[[ \$- = *i* ]] && source /opt/liquidprompt/liquidprompt' >> ~/.bashrc
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/initial_server_setup/liquidpromptrc -O ~/.config/liquidpromptrc
EOF

## some settings for bitrix

# less priority for swap
echo vm.swappiness=1 >> /etc/sysctl.d/90-override.conf && sysctl -p

# systemd's units autorestart
mkdir -p /etc/systemd/system/nginx.service.d && echo -e '[Service]\nRestart=on-failure' >> /etc/systemd/system/nginx.service.d/override.conf && echo -e '[Service]\nRestart=on-failure' >> /etc/systemd/system/httpd.service.d/override.conf && mkdir -p /etc/systemd/system/memcached.service.d && echo -e '[Service]\nRestart=on-failure' >> /etc/systemd/system/memcached.service.d/override.conf && systemctl daemon-reload

# nginx settings
echo 'gzip_vary on;' >> /etc/nginx/bx/settings/z_bx_custom.conf
systemctl reload nginx

# php settings
cat <<EOT >> /etc/php.d/z_bx_custom.ini
allow_url_fopen = Off
mail.add_x_header = Off
pcre.recursion_limit = 100000
EOT
systemctl reload httpd

# system limits
echo -e 'root soft nproc unlimited\n* soft nproc 65535\n* hard nproc 65535\n* soft nofile 100000\n* hard nofile 100000' > /etc/security/limits.d/20-nproc.conf  && sysctl -p

# mysql limits
mkdir -p /etc/systemd/system/mysqld.service.d && echo -e '[Service]\nLimitNPROC=65535\nLimitNOFILE=100000'  >> /etc/systemd/system/mysqld.service.d/override.conf && systemctl daemon-reload

# ntpd often desync
systemctl stop ntpd
systemctl disable ntpd
systemctl enable chronyd
systemctl restart chronyd

# mysql add template config
curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/initial_server_setup/mysql_setup.sh | bash

echo "Do you wish to install postfix?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/initial_server_setup/postfix.sh | bash ; break;;
        No ) exit;;
    esac
done

echo "Do you wish to install zabbix?"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
                read -p "Please enter a ip of zabbix server : " server_ip
                read -p "Please enter a zabbix server domain : " domain
                read -p "Please enter a hostname for this zabbix node : " hostname

                curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/zabbix.sh | bash -s -- ${server_ip} ${domain} ${hostname}  ; break;;

        No ) exit;;
    esac
done

echo "Do you wish to install antivirus?"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
                read -p "Please enter your email : " your_mail

                curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/av_setup.sh | bash -s -- ${your_mail}  ; break;;

        No ) exit;;
    esac
done


echo "Do you wish to install backup_script?"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
                read -p "Please enter your sitename : " sitename

                curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/auto_setup.sh | bash -s -- /home/bitrix/www ${sitename}_\`date\ \+\\%Y\.\\%m\.\\%d\-\\%H\.\\%M\`  ; break;;

        No ) exit;;
    esac
done
