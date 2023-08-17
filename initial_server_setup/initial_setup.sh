#!/usr/bin/env bash
set -eo pipefail
# use
# bash <(curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/initial_server_setup/initial_setup.sh)

# wget http://www.1c-bitrix.ru/download/files/scripts/bitrix_server_test.php -P /home/bitrix/www/

# https://marketplace.1c-bitrix.ru/solutions/dev2fun.imagecompress/
# cd /home/bitrix/www/upload/
# find -type f -name "*.jpg" -exec jpegoptim --strip-all --all-progressive {} \;
# find -type f -name "*.jpeg" -exec jpegoptim --strip-all --all-progressive {} \;
# find -type f -name "*.png" -exec optipng -o7 {} \;

# install useful programms
yum -y install --enablerepo=epel wget byobu chrony net-tools certbot ncdu iotop htop bind-utils traceroute mc bash-completion bash-completion-extras yum-utils nano tmux deltarpm jpegoptim optipng libwebp-tools ImageMagick php-pecl-imagick mysqltuner smem
# gifsicle ghostscript nodejs
# npm install -g svgo

# install liquidprompt
#cd /opt/ && git clone https://github.com/nojhan/liquidprompt
mkdir -p /opt/liquidprompt
# ver 2.0.1
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/initial_server_setup/liquidprompt -N -O /opt/liquidprompt/liquidprompt

cat <<\EOT >> ~/.bashrc
alias mc='mc -x'
#alias mytuner='curl -sL https://raw.github.com/major/MySQLTuner-perl/master/mysqltuner.pl | perl'
#alias myprimer='curl -sL https://raw.githubusercontent.com/RootService/tuning-primer/master/tuning-primer.sh | bash'
#alias a2bud='curl -sL https://raw.githubusercontent.com/richardforth/apache2buddy/master/apache2buddy.pl | perl'
alias door='wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/test.php'
alias lst='ls -alt --time-style=long-iso'
alias ncdu='ncdu --color off'
[[ $- = *i* ]] && source /opt/liquidprompt/liquidprompt
export VISUAL=nano
EOT

ssh-keygen -t ed25519 -q -f "$HOME/.ssh/ed25519" -N ""

mkdir -p ~/.config/htop
mkdir -p /opt/letsencrypt/
chown bitrix. /opt/letsencrypt/
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/initial_server_setup/htoprc -N -P ~/.config/htop/
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/initial_server_setup/liquidpromptrc -N -O ~/.config/liquidpromptrc
source /opt/liquidprompt/liquidprompt

# nano syntax highlighting
touch ~/.nanorc &&  find /usr/share/nano -name '*.nanorc' -printf "include %p\n" > ~/.nanorc

tuned-adm profile virtual-guest

sudo -i -u bitrix bash << EOF
mkdir ~/.config
echo -e "alias mc='mc -x'" >> ~/.bashrc
echo -e "alias lst='ls -alt --time-style=long-iso'" >> ~/.bashrc
echo -e '[[ \$- = *i* ]] && source /opt/liquidprompt/liquidprompt' >> ~/.bashrc
echo -e 'export VISUAL=nano' >> ~/.bashrc
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/initial_server_setup/liquidpromptrc -N -O ~/.config/liquidpromptrc
touch ~/.nanorc
find /usr/share/nano -name '*.nanorc' -printf "include %p\n" > ~/.nanorc
ssh-keygen -t ed25519 -q -f "/home/bitrix/.ssh/ed25519" -N ""
touch "/home/bitrix/.ssh/authorized_keys"
chmod 644 "/home/bitrix/.ssh/authorized_keys"
EOF

# secure purpose
chown root. /home/bitrix/.ssh/authorized_keys

# let's encrypt
mkdir -p /etc/letsencrypt/renewal-hooks/deploy/
echo -e '#!/bin/sh\nservice nginx reload' > /etc/letsencrypt/renewal-hooks/deploy/nginx.sh
chmod +x /etc/letsencrypt/renewal-hooks/deploy/nginx.sh

cat <<EOT > /etc/sysconfig/certbot
## NOTE ##
# If a hook is set here then it will be used for all
# certificates and will override any per certificate
# hook configuration in place.

# Command to be run in a shell before obtaining any
# certificates. Intended primarily for renewal, where it
# can be used to temporarily shut down a webserver that
# might conflict with the standalone plugin. This will
# only be called if a certificate is actually to be
# obtained/renewed. When renewing several certificates
# that have identical pre-hooks, only the first will be
# executed.
#
# An example to stop the MTA before updating certs would be
# PRE_HOOK="--pre-hook 'systemctl stop postfix'"
PRE_HOOK=""

# Command to be run in a shell after attempting to
# obtain/renew certificates. Can be used to deploy
# renewed certificates, or to restart any servers that
# were stopped by --pre-hook. This is only run if an
# attempt was made to obtain/renew a certificate. If
# multiple renewed certificates have identical post-
# hooks, only one will be run.
#
# An example to restart httpd would be:
# POST_HOOK="--post-hook 'systemctl restart httpd'"
POST_HOOK=""

# Command to be run in a shell once for each
# successfully renewed certificate. For this command,
# the shell variable $RENEWED_LINEAGE will point to the
# config live subdirectory containing the new certs and
# keys; the shell variable $RENEWED_DOMAINS will contain
# a space-delimited list of renewed cert domains
#
# An example to run a script to alert each cert would be:
# DEPLOY_HOOK="--deploy-hook /usr/local/bin/cert-notifier.sh"
DEPLOY_HOOK="--deploy-hook 'systemctl reload nginx'"

# Any other misc arguments for the renewal
# See certbot -h renew for full list
#
# An example to force renewal for certificates not due yet
# CERTBOT_ARGS="--force-renewal"
CERTBOT_ARGS="--allow-subset-of-names"
EOT

systemctl enable certbot-renew.timer && systemctl start certbot-renew.timer

## some settings for bitrix

# systemd's units autorestart
mkdir -p /etc/systemd/system/nginx.service.d && echo -e '[Service]\nRestart=on-failure\nRestartSec=5\nLimitNPROC=65535\nLimitNOFILE=1000000' >> /etc/systemd/system/nginx.service.d/override.conf && mkdir -p /etc/systemd/system/httpd.service.d && echo -e '[Service]\nRestart=on-failure\nRestartSec=5\nLimitNPROC=65535\nLimitNOFILE=1000000' >> /etc/systemd/system/httpd.service.d/override.conf && mkdir -p /etc/systemd/system/memcached.service.d && echo -e '[Service]\nRestart=on-failure\nRestartSec=5\nLimitNPROC=65535\nLimitNOFILE=1000000' >> /etc/systemd/system/memcached.service.d/override.conf && systemctl daemon-reload

# nginx settings
# pagespeed: rollback gzip, explicit configuration in /etc/nginx/bx/settings/z_bx_custom.conf:1
echo 'gzip_vary on;' >> /etc/nginx/bx/settings/z_bx_custom.conf
#echo 'server_tokens off;' >> /etc/nginx/bx/settings/z_bx_custom.conf	
systemctl reload nginx

# php settings
cat <<EOT >> /etc/php.d/z_bx_custom.ini
;allow_url_fopen = Off
;allow_url_include = Off
;disable_functions=eval,exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source
mail.add_x_header = Off
pcre.recursion_limit = 100000
cgi.fix_pathinfo = 0
max_input_vars = 100000
;error_reporting = E_ALL & ~E_NOTICE & ~E_DEPRECATED
EOT
mv -f /etc/php.d/20-curl.ini.disabled /etc/php.d/20-curl.ini

# security
# yum install php-snuffleupagus -y
# wget https://raw.githubusercontent.com/jvoisin/snuffleupagus/master/config/default_php8.rules -N -O /etc/php.d/snuffleupagus-default_php8.rules
# php 7
# wget https://raw.githubusercontent.com/jvoisin/snuffleupagus/master/config/default.rules -N -O /etc/php.d/snuffleupagus-default_php7.rules

# system limits
echo -e 'root soft nproc unlimited\n* soft nproc 65535\n* hard nproc 65535\n* soft nofile 1000000\n* hard nofile 1000000' > /etc/security/limits.d/20-nproc.conf  && sysctl --system

curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/initial_server_setup/sysctl.sh | bash
curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/initial_server_setup/mydumper_cnf_setup.sh | bash


# mysql limits
mkdir -p /etc/systemd/system/mysqld.service.d && echo -e '[Service]\nRestartSec=5\nLimitNPROC=65535\nLimitNOFILE=1000000'  >> /etc/systemd/system/mysqld.service.d/override.conf && systemctl daemon-reload

# ntpd often desync
systemctl stop ntpd
systemctl disable ntpd
systemctl enable chronyd
systemctl restart chronyd

systemctl stop stunnel.service
systemctl disable stunnel
systemctl stop httpd-scale.service
systemctl disable httpd-scale.service
find /etc/cron.d/bx_httpd-scale -type f -print0 | xargs -0 sed -i 's/* * * * */#* * * * */g' 

# mysql add template config
curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/initial_server_setup/mysql_setup.sh | bash

# nginx additional settings
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/nginx/ssl.common.conf -N -P /etc/nginx/bx/conf/
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/nginx/block_access.conf -N -P /etc/nginx/
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/nginx/.htpasswd -N -P /etc/nginx/
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/nginx/brotli.conf -N -P /etc/nginx/bx/settings/

mkdir -p /etc/nginx/bx/site_settings/default/
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/nginx/qrator.conf -N -P /etc/nginx/bx/maps/
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/nginx/acme_well_known.conf -N -P /etc/nginx/bx/site_settings/default/
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/nginx/locations.conf -N -P /etc/nginx/bx/site_settings/default/
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/nginx/seo.conf -N -P /etc/nginx/bx/site_settings/default/

# block ip access
curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/nginx/bx_ext_ip.sh | bash -s

# limit_req
# wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/nginx/limit_req/map/ddos.conf  -N -P /etc/nginx/bx/maps/
# wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/nginx/limit_req/settings/ddos.conf  -N -P /etc/nginx/bx/settings/
# wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/nginx/limit_req/site_settings/default/ddos.conf  -N -P /etc/nginx/bx/site_settings/default/

# cf updater
# wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/nginx/cloudflare_ip_updater.sh -N -P /etc/cron.daily/


#find /etc/nginx/bx/site_avaliable/s* -type f -print0 | xargs -0 sed -i 's/all\ websites/all\ websites\n\ include\ bx\/site_settings\/default\/\*\.conf\;/g'

nginx -t && systemctl reload nginx

# logrotate
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/initial_server_setup/bitrixlog -N -P /etc/logrotate.d/

# disable httpd access logs
find /etc/httpd/ -type f -print0 | xargs -0 sed -i 's/CustomLog/#CustomLog/g'
# set real ip in httpd logs
find /etc/httpd/ -type f -print0 | xargs -0 sed -i 's/LogFormat "%h/LogFormat "%a/g' 
#LogFormat "%h

systemctl reload httpd

echo "Do you wish to install postfix?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) bash <(curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/initial_server_setup/postfix.sh) ; break;;
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

                curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/auto_setup.sh | bash -s -- /home/bitrix/www ; break;;

        No ) exit;;
    esac
done

echo "Do you wish to install gitlab-runner?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/git/runner.sh | bash ; break;;
        No ) exit;;
    esac
done
