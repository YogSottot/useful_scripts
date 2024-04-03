#!/usr/bin/env bash
set -euo pipefail
# use
# curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/nginx/bx_ext_ip.sh | bash -s

#ip=`ip -4  addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'`
#ip=`ip a | grep -Po '(?!(inet 127.\d.\d.1))(inet \K(\d{1,3}\.){3}\d{1,3})'`
ip=`hostname -I`

cat <<EOT > /etc/nginx/bx/site_avaliable/bx_ext_ip.conf
server {
    listen 80;
    listen [::]:80;
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    
    server_name ${ip};
    
    ssl_reject_handshake on;

    
    location / {
        return 444;
    }
}
EOT

cd /etc/nginx/bx/site_enabled/ && \
ln -s ../site_avaliable/bx_ext_ip.conf . && \
nginx -t && \
systemctl reload nginx
