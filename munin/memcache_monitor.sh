#!/usr/bin/env bash
set -e
# use
# wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/munin/memcache_monitor.sh -P /opt && chmod +x /opt/memcache_monitor.sh

# add to crontab
# */5 * * * * /opt/memcache_monitor.sh > /dev/null 2>&1

if  /usr/bin/timeout -k 5 15 /usr/bin/memcached-tool /tmp/memcached.sock stats ; then
        exit 0
else
        systemctl restart memcached.service
fi
