#!/usr/bin/env bash

# if AS815 AS10439 AS14061
# curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/fail2ban/firewalld-asn.sh | bash -s -- 815 10439 14061
# wget  https://raw.githubusercontent.com/YogSottot/useful_scripts/master/fail2ban/firewalld-asn.sh
# chmod +x firewalld-asn.sh
#ASN="$1"
mkdir -p /tmp/ASN/

for ASN in "$@"
do
## Remove and delete ${ASN}-4 ipset if it exists
if firewall-cmd --permanent --get-ipsets | grep -q "${ASN}-4"; then
  firewall-cmd --permanent --zone=drop --remove-source=ipset:${ASN}-4
  firewall-cmd --permanent --delete-ipset=${ASN}-4
  firewall-cmd --reload
fi

## Remove and delete ${ASN}-6 ipset if it exists
if firewall-cmd --permanent --get-ipsets | grep -q "${ASN}-6"; then
  firewall-cmd --permanent --zone=drop --remove-source=ipset:${ASN}-6
  firewall-cmd --permanent --delete-ipset=${ASN}-6
  firewall-cmd --reload
fi

# get list from https://asn.ipinfo.app
wget https://asn.ipinfo.app/api/download/list/AS${ASN} -O /tmp/ASN/${ASN}
# sort ipv4 and ipv6
grep ':' /tmp/ASN/${ASN} > /tmp/ASN/${ASN}-6
grep -F '.' /tmp/ASN/${ASN} > /tmp/ASN/${ASN}-4

# make ipset
firewall-cmd --permanent --new-ipset=${ASN}-4 --type=hash:net --option=maxelem=1000000 --option=hashsize=4096 --option=family=inet
firewall-cmd --permanent --new-ipset=${ASN}-6 --type=hash:net --option=maxelem=1000000 --option=hashsize=4096 --option=family=inet6

# block this ipset
firewall-cmd --permanent --zone=drop --add-source=ipset:${ASN}-4
firewall-cmd --permanent --zone=drop --add-source=ipset:${ASN}-6

# load ip list from files
firewall-cmd --permanent --ipset=${ASN}-4 --add-entries-from-file=/tmp/ASN/${ASN}-4
firewall-cmd --permanent --ipset=${ASN}-6 --add-entries-from-file=/tmp/ASN/${ASN}-6

done

# reload firewalld
firewall-cmd --reload

# clean dir
rm -rf  /tmp/ASN/

# if want to delete whole ipset
# firewall-cmd --permanent --delete-ipset=<ipset>

# if want to del one entry
# firewall-cmd  --permanent --ipset=<ipset> --remove-entry=192.168.1.7

# --info-ipset=<ipset> Print information about an ipset
# --get-ipsets Print predefined ipsets
# --ipset=<ipset> --query-entry=<entry> Return whether ipset has an entry [P]
# --ipset=<ipset> --get-entries List entries of an ipset [P]
# --ipset=<ipset> --remove-entries-from-file=<entry> Remove entries from an ipset [P]
# firewall-cmd --permanent --zone=drop --remove-source=

# block country
# https://github.com/vtgcyberjunkie/firewalld-block-ipset/blob/master/firewalld-block-ipset.sh
