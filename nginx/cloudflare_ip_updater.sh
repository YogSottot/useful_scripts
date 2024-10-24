#!/usr/bin/env bash
set -eo pipefail


CLOUDFLARE_IP_RANGES_FILE_PATH="/etc/nginx/bx/maps/cloudflare.conf"
WWW_GROUP="root"
WWW_USER="root"


CLOUDFLARE_IPSV4_REMOTE_FILE="https://www.cloudflare.com/ips-v4"
CLOUDFLARE_IPSV6_REMOTE_FILE="https://www.cloudflare.com/ips-v6"
CLOUDFLARE_IPSV4_LOCAL_FILE="/tmp/cloudflare-ips-v4"
CLOUDFLARE_IPSV6_LOCAL_FILE="/tmp/cloudflare-ips-v6"


if [ -f /usr/bin/fetch ];
then
    fetch $CLOUDFLARE_IPSV4_REMOTE_FILE --no-verify-hostname --no-verify-peer -o $CLOUDFLARE_IPSV4_LOCAL_FILE --quiet
    fetch $CLOUDFLARE_IPSV6_REMOTE_FILE --no-verify-hostname --no-verify-peer -o $CLOUDFLARE_IPSV6_LOCAL_FILE --quiet
else
    wget -q $CLOUDFLARE_IPSV4_REMOTE_FILE -O $CLOUDFLARE_IPSV4_LOCAL_FILE --no-check-certificate
    wget -q $CLOUDFLARE_IPSV6_REMOTE_FILE -O $CLOUDFLARE_IPSV6_LOCAL_FILE --no-check-certificate
fi


echo "# CloudFlare IP Ranges" > $CLOUDFLARE_IP_RANGES_FILE_PATH
echo "# Generated at $(date) by $0" >> $CLOUDFLARE_IP_RANGES_FILE_PATH
echo "" >> $CLOUDFLARE_IP_RANGES_FILE_PATH
echo "# IPs v4" >> $CLOUDFLARE_IP_RANGES_FILE_PATH
awk '{ print "set_real_ip_from " $0 ";" }' $CLOUDFLARE_IPSV4_LOCAL_FILE >> $CLOUDFLARE_IP_RANGES_FILE_PATH
echo "" >> $CLOUDFLARE_IP_RANGES_FILE_PATH
echo "# IPs v6" >> $CLOUDFLARE_IP_RANGES_FILE_PATH
awk '{ print "set_real_ip_from " $0 ";" }' $CLOUDFLARE_IPSV6_LOCAL_FILE >> $CLOUDFLARE_IP_RANGES_FILE_PATH
echo "" >> $CLOUDFLARE_IP_RANGES_FILE_PATH
#echo "# Getting real ip from CF-Connecting-IP header" >> $CLOUDFLARE_IP_RANGES_FILE_PATH
#echo "real_ip_header CF-Connecting-IP;" >> $CLOUDFLARE_IP_RANGES_FILE_PATH
echo "" >> $CLOUDFLARE_IP_RANGES_FILE_PATH


chown $WWW_USER:$WWW_GROUP $CLOUDFLARE_IP_RANGES_FILE_PATH

# cloudflare_firewalld
# cat $CLOUDFLARE_IPSV4_LOCAL_FILE > /tmp/cloudflare-ips
# echo "" >> /tmp/cloudflare-ips
# cat $CLOUDFLARE_IPSV6_LOCAL_FILE >> /tmp/cloudflare-ips
# echo "" >> /tmp/cloudflare-ips
# cat /opt/backup/cloudflare_custom_ip.txt >> /tmp/cloudflare-ips
# /opt/backup/cloudflare_firewalld.sh /tmp/cloudflare-ips


rm -rf $CLOUDFLARE_IPSV4_LOCAL_FILE
rm -rf $CLOUDFLARE_IPSV6_LOCAL_FILE


nginx -t && systemctl reload nginx.service
