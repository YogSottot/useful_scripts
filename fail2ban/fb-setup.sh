#!/usr/bin/env bash
set -e
# https://github.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/blob/master/AUTO-CONFIGURATION.md
# https://github.com/mitchellkrogza/Fail2Ban-Blacklist-JAIL-for-Repeat-Offenders-with-Perma-Extended-Banning

# use curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/fail2ban/fb-setup.sh | bash

yum install fail2ban -y

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

# Ban hosts for one hour:
bantime = 3600
destemail =
# A host is banned if it has generated "maxretry" during the last "findtime"
# seconds.
findtime = 600

#bantime = 1m
#bantime.increment = true
#bantime.factor = 2
#bantime.maxtime = 2w
#maxretry = 3
#findtime = 1d


[sshd]
enabled = true
maxretry = 4

[sshd-ddos]
enabled = true

[nginx-http-auth]
enabled = false

[apache-auth]
enabled = false

[proftpd]
enabled = true
# fix NOTICE  Jail started without 'journalmatch' set.
backend  = polling
journalmatch =

[nginxrepeatoffender]
enabled = false
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
# until it will be fixed or 0.11 with ban-increment released https://github.com/fail2ban/fail2ban/issues/1379
#logpath  = /var/log/fail2ban.*
logpath  = /var/log/fail2ban.log
filter = blacklist
banaction = blacklist
bantime  = 31536000   ; 1 year
findtime = 31536000   ; 1 year
maxretry = 10

[nginx-x00]
enabled  = true
port     = http,https
filter   = nginx-x00
logpath  = %(nginx_access_log)s
bantime  = 86400
maxretry = 1

[nginx-wordpress]
enabled  = true
port     = http,https
filter   = nginx-wordpress
logpath  = %(nginx_access_log)s
bantime  = 86400
maxretry = 1

[nginx-scripts]
enabled  = false
port     = http,https
filter   = nginx-scripts
logpath  = %(nginx_access_log)s
bantime  = 86400
maxretry = 1

[nginx-shells]
enabled  = true
port     = http,https
filter   = nginx-shells
logpath  = %(nginx_access_log)s
bantime  = 86400
maxretry = 1

[nginx-referrer-spam]
enabled  = false
port     = http,https
filter   = nginx-referrer-spam
logpath  = %(nginx_access_log)s
bantime  = 86400
maxretry = 2


EOT

# Fail2Ban-Blacklist
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/fail2ban/filter.d/nginxrepeatoffender.conf -N -P /etc/fail2ban/filter.d/

wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/fail2ban/filter.d/nginx-x00.conf -N -P /etc/fail2ban/filter.d/

wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/fail2ban/filter.d/nginx-wordpress.conf -N -P /etc/fail2ban/filter.d/

wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/fail2ban/filter.d/nginx-scripts.conf -N -P /etc/fail2ban/filter.d/

wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/fail2ban/filter.d/nginx-shells.conf -N -P /etc/fail2ban/filter.d/

wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/fail2ban/filter.d/nginx-referrer-spam.conf -N -P /etc/fail2ban/filter.d/

wget https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/_fail2ban_addon/action.d/nginxrepeatoffender.conf -N -O /etc/fail2ban/action.d/nginxrepeatoffender.conf

wget https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/_fail2ban_addon/filter.d/nginx-limit-req.local -N -O /etc/fail2ban/filter.d/nginx-limit-req.local

wget https://raw.githubusercontent.com/mitchellkrogza/Fail2Ban-Blacklist-JAIL-for-Repeat-Offenders-with-Perma-Extended-Banning/master/filter.d/blacklist.conf -N -O /etc/fail2ban/filter.d/blacklist.conf

wget https://raw.githubusercontent.com/mitchellkrogza/Fail2Ban-Blacklist-JAIL-for-Repeat-Offenders-with-Perma-Extended-Banning/master/action.d/blacklist.conf -N -O /etc/fail2ban/action.d/blacklist.conf

touch /etc/fail2ban/ip.blacklist
chmod 755 /etc/fail2ban/ip.blacklist

systemctl enable fail2ban.service && systemctl restart fail2ban.service

echo "Do not forget to add ignore ip to fail2ban and botblock"

