#!/bin/bash
#ipset -X badips
#ipset -N badips hash:ip hashsize 16777216 maxelem 16777216
/usr/bin/wget http://domain.tld/block.txt -O /opt/backup/block.txt
while read ipaddr
do
        ipset -A badips "$ipaddr";
done </opt/backup/block.txt | sort | uniq
#iptables -I PREROUTING -m set --match-set badips src -j DROP
#iptables-save
#service nginx restart
#service httpd restart

