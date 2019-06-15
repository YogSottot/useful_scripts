#!/usr/bin/env bash
set -e
# use
# wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/munin/memcache_monitor.sh -P /opt && chmod +x /opt/memcache_monitor.sh

# add to crontab
# */5 * * * * /opt/memcache_monitor.sh > /dev/null 2>&1

/usr/bin/timeout -k 5 15 /usr/bin/memcached-tool /tmp/memcached.sock stats

if (($? == 124)); then
  systemctl restart memcached.service
  exit 124
fi

if (($? == 137)); then
  systemctl restart memcached.service
  exit 124
fi

if (($? == 128+9)); then
  systemctl restart memcached.service
  exit 124
fi
