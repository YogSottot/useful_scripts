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
sendmail_path = sendmail -t -i
EOT
systemctl reload httpd

# system limits
echo -e 'root soft nproc unlimited\n* soft nproc 65535\n* hard nproc 65535\n* soft nofile 100000\n* hard nofile 100000' > /etc/security/limits.d/20-nproc.conf  && sysctl -p

# mysql limits
mkdir -p /etc/systemd/system/mysqld.service.d && echo -e '[Service]\nLimitNPROC=65535\nLimitNOFILE=100000'  >> /etc/systemd/system/mysqld.service.d/override.conf && systemctl daemon-reload

# mail
yum install postfix -y

# postfix limits
mkdir -p /etc/systemd/system/postfix.service.d && echo -e '[Service]\nLimitNPROC=65535\nLimitNOFILE=100000'  >> /etc/systemd/system/postfix.service.d/override.conf && systemctl daemon-reload

cat <<EOT >> /etc/postfix/main.cf
#default_destination_concurrency_limit = 500
#default_destination_recipient_limit = 500
#initial_destination_concurrency = 50
#fork_delay = 1s
#in_flow_delay = 1s
#smtpd_recipient_limit = 30000
#mydestination =
#mynetworks_style = host
#fallback_transport = relay
# mydestination = localhost.$mydomain, localhost
EOT

systemctl enable postfix && systemctl restart postfix

# mysql add template config
curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/initial_server_setup/mysql_setup.sh | bash