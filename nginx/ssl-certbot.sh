#!/usr/bin/env bash

domain=$2
path=$1

if [ -z ${domain} ]; then
        echo Usage: $0 path domain Example: $0 /home/bitrix/ext_www/domain.tld domain.tld
        exit
fi

if [ -z ${path} ]; then
        echo Usage: $0 path domain Example: $0 /home/bitrix/ext_www/domain.tld domain.tld
        exit
fi


certbot --agree-tos -m notify@monitorim.site --staple-ocsp --webroot certonly -w ${path} -d ${domain} -d www.${domain} && \

find /etc/nginx/bx/site_avaliable_fpm/bx_ext_ssl_${domain}.conf  -type f -print0 | xargs -0 sed -i -r 's/include\ bx\/conf\/ssl\.conf\;/include\ bx\/conf\/ssl\.common\.conf;\nssl_certificate\ \/etc\/letsencrypt\/live\/'${domain.tld}'\/fullchain\.pem\;\nssl_certificate_key\ \/etc\/letsencrypt\/live\/'${domain.tld}'\/privkey\.pem\;\nssl_trusted_certificate\ \/etc\/letsencrypt\/live\/'${domain.tld}'\/chain\.pem\;\n/g'


nginx -t && systemctl reload nginx
