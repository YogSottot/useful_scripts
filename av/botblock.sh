#!/usr/bin/env bash

# https://github.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/blob/master/AUTO-CONFIGURATION.md
# https://github.com/mitchellkrogza/Fail2Ban-Blacklist-JAIL-for-Repeat-Offenders-with-Perma-Extended-Banning

# use curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/botblock.sh | bash

yum -y install bind-utils
wget https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/install-ngxblocker -O /usr/local/sbin/install-ngxblocker
chmod +x /usr/local/sbin/install-ngxblocker
/usr/local/sbin/install-ngxblocker -c /etc/nginx/bx/settings -x
/usr/local/sbin/setup-ngxblocker -v /etc/nginx/bx/site_avaliable -c /etc/nginx/bx/settings -e conf -x

cat <<EOT >>/etc/nginx/bots.d/blacklist-user-agents.conf
        "~*\bUptimeRobot\b"     0;
        "~*\bYandexBot\b"       0;
        "~*\bYandexImages\b"    0;
        "~*\bMail.ru\b"         0;
EOT

cat <<EOT >>/etc/nginx/bots.d/whitelist-domains.conf
        "~*\bwebvisor\.com\b"         0;
        "~*\bwww\.uptimerobot\.com\b" 0;
EOT

cat <<EOT >>/etc/nginx/bots.d/custom-bad-referrers.conf
        "~*\baway\.vk\.com\b"   0;
EOT

crontab -l | { cat; echo "00 22 * * * /usr/local/sbin/update-ngxblocker -c /etc/nginx/bx/settings -n > /dev/null 2>&1 || true" ; } | crontab -

# Fail2Ban local configuration file
if [ ! -f /var/log/fail2ban.log ];then
touch /var/log/fail2ban.log
fi

cat <<EOT >> /etc/fail2ban/fail2ban.local
[Definition]
dbpurgeage = 648000
EOT
cat <<EOT >> /etc/fail2ban/jail.local
[DEFAULT]
ignoreip = 127.0.0.1/8 38.123.140.0/24
# Default banning action (e.g. iptables, iptables-new,
# iptables-multiport, shorewall, etc) It is used to define
# action_* variables. Can be overridden globally or per
# section within jail.local file
banaction = iptables-multiport
banaction_allports = iptables-allports

# Ban hosts for one hour:
bantime = 3600
destemail =
# A host is banned if it has generated "maxretry" during the last "findtime"
# seconds.
findtime = 600

[sshd]
enabled = true
maxretry = 4

[sshd-ddos]
enabled = true

[nginx-http-auth]
enabled = true

[apache-auth]
enabled = true

[proftpd]
enabled = true
backend  = polling
journalmatch =

[nginxrepeatoffender]
enabled = true
logpath = %(nginx_access_log)s
filter = nginxrepeatoffender
banaction = nginxrepeatoffender
bantime  = 86400   ; 1 day
findtime = 604800   ; 1 week
maxretry = 20

[nginx-limit-req]
enabled = true
port    = http,https
filter = nginx-limit-req
logpath = %(nginx_error_log)s
maxretry = 1

[blacklist]
enabled = true
logpath  = /var/log/fail2ban.*
filter = blacklist
banaction = blacklist
bantime  = 31536000   ; 1 year
findtime = 31536000   ; 1 year
maxretry = 10
EOT

# Fail2Ban-Blacklist
wget https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/_fail2ban_addon/action.d/nginxrepeatoffender.conf -O /etc/fail2ban/action.d/nginxrepeatoffender.conf

wget https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/_fail2ban_addon/filter.d/nginx-limit-req.local  -O /etc/fail2ban/filter.d/nginx-limit-req.local

wget https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/_fail2ban_addon/filter.d/nginxrepeatoffender.conf  -O /etc/fail2ban/filter.d/nginxrepeatoffender.conf

wget https://raw.githubusercontent.com/mitchellkrogza/Fail2Ban-Blacklist-JAIL-for-Repeat-Offenders-with-Perma-Extended-Banning/master/filter.d/blacklist.conf -O /etc/fail2ban/filter.d/blacklist.conf

wget https://raw.githubusercontent.com/mitchellkrogza/Fail2Ban-Blacklist-JAIL-for-Repeat-Offenders-with-Perma-Extended-Banning/master/action.d/blacklist.conf -O /etc/fail2ban/action.d/blacklist.conf

touch /etc/fail2ban/ip.blacklist
chmod 755 /etc/fail2ban/ip.blacklist

systemctl enable fail2ban.service && systemctl restart fail2ban.service

echo "Do not forget to add ignore ip to fail2ban and botblock"
nginx -t
