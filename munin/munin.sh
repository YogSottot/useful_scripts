#!/usr/bin/env bash

# use
# bash <(curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/munin/munin.sh)

# systemd's units change
mkdir -p /etc/systemd/system/munin-node.service.d && echo -e '[Service]\nRestart=on-failure\nLimitNPROC=65535\nLimitNOFILE=100000\nLimitSTACK=infinity\nPrivateTmp=false' >> /etc/systemd/system/munin-node.service.d/override.conf && systemctl daemon-reload 

# plugin support unix-socket
wget https://raw.githubusercontent.com/mhwest13/Memcached-Munin-Plugin/master/memcached_ -N -O /usr/share/munin/plugins/memcached2_
chmod +x /usr/share/munin/plugins/memcached2_

ln -s '/usr/share/munin/plugins/memcached2_' '/etc/munin/plugins/memcached_bytes' && ln -s '/usr/share/munin/plugins/memcached2_' '/etc/munin/plugins/memcached_commands' && ln -s '/usr/share/munin/plugins/memcached2_' '/etc/munin/plugins/memcached_conns' && ln -s '/usr/share/munin/plugins/memcached2_' '/etc/munin/plugins/memcached_evictions' && ln -s '/usr/share/munin/plugins/memcached2_' '/etc/munin/plugins/memcached_items' && ln -s '/usr/share/munin/plugins/memcached2_' '/etc/munin/plugins/memcached_memory'

echo -e '[memcached_*]\nuser bitrix\nenv.host unix:///tmp/memcached.sock\nenv.port 0\nenv.timescale 3\nenv.cmds get set delete incr decr touch\nenv.leitime -1' > /etc/munin/plugin-conf.d/memcache

systemctl restart munin-node
