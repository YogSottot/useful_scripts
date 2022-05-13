#!/usr/bin/env bash
set -e
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
[[ $- = *i* ]] && source /opt/liquidprompt/liquidprompt
export VISUAL=nano
EOT

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
EOF

## some settings for bitrix

# systemd's units autorestart
mkdir -p /etc/systemd/system/nginx.service.d && echo -e '[Service]\nRestart=on-failure\nLimitNPROC=65535\nLimitNOFILE=1000000' >> /etc/systemd/system/nginx.service.d/override.conf && mkdir -p /etc/systemd/system/httpd.service.d && echo -e '[Service]\nRestart=on-failure\nLimitNPROC=65535\nLimitNOFILE=1000000' >> /etc/systemd/system/httpd.service.d/override.conf && mkdir -p /etc/systemd/system/memcached.service.d && echo -e '[Service]\nRestart=on-failure\nLimitNPROC=65535\nLimitNOFILE=1000000' >> /etc/systemd/system/memcached.service.d/override.conf && systemctl daemon-reload

# nginx settings
# pagespeed: rollback gzip, explicit configuration in /etc/nginx/bx/settings/z_bx_custom.conf:1
echo 'gzip_vary on;' >> /etc/nginx/bx/settings/z_bx_custom.conf
#echo 'server_tokens off;' >> /etc/nginx/bx/settings/z_bx_custom.conf	
systemctl reload nginx

# php settings
cat <<EOT >> /etc/php.d/z_bx_custom.ini
;allow_url_fopen = Off
mail.add_x_header = Off
pcre.recursion_limit = 100000
cgi.fix_pathinfo = 0
max_input_vars = 100000
error_reporting = E_ALL & ~E_NOTICE & ~E_DEPRECATED
EOT
mv -f /etc/php.d/20-curl.ini.disabled /etc/php.d/20-curl.ini
systemctl reload httpd

# system limits
echo -e 'root soft nproc unlimited\n* soft nproc 65535\n* hard nproc 65535\n* soft nofile 1000000\n* hard nofile 1000000' > /etc/security/limits.d/20-nproc.conf  && sysctl --system

curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/initial_server_setup/sysctl.sh | bash

# mysql limits
mkdir -p /etc/systemd/system/mysqld.service.d && echo -e '[Service]\nLimitNPROC=65535\nLimitNOFILE=1000000'  >> /etc/systemd/system/mysqld.service.d/override.conf && systemctl daemon-reload

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
