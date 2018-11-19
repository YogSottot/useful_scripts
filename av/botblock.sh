#!/usr/bin/env bash

# https://github.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/blob/master/AUTO-CONFIGURATION.md
# https://github.com/mitchellkrogza/Fail2Ban-Blacklist-JAIL-for-Repeat-Offenders-with-Perma-Extended-Banning

# use curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/botblock.sh | bash

yum -y install bind-utils
wget https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/install-ngxblocker -N -O /usr/local/sbin/install-ngxblocker
chmod +x /usr/local/sbin/install-ngxblocker
/usr/local/sbin/install-ngxblocker -c /etc/nginx/bx/settings -x
/usr/local/sbin/setup-ngxblocker -v /etc/nginx/bx/site_avaliable -c /etc/nginx/bx/settings -e conf -x

cat <<EOT >>/etc/nginx/bots.d/blacklist-user-agents.conf
        "~*\bUptimeRobot\b"     0;
        "~*\bYandexBot\b"       0;
        "~*\bYandexImages\b"    0;
        "~*\bUptimeRobot/2.0\b" 0;
        
        "~*\bbingbot\b"         3;
EOT

cat <<EOT >>/etc/nginx/bots.d/whitelist-domains.conf
        "~*\bwebvisor\.com\b"         0;
        "~*\bwww\.uptimerobot\.com\b" 0;
EOT

cat <<EOT >>/etc/nginx/bots.d/custom-bad-referrers.conf
        "~*\baway\.vk\.com\b"   0;
        "~*\bok\.ru\b"  0;
EOT

crontab -l | { cat; echo "00 22 * * * /usr/local/sbin/update-ngxblocker -c /etc/nginx/bx/settings -n > /dev/null 2>&1 || true" ; } | crontab -


curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/fail2ban/fb-setup.sh | bash
