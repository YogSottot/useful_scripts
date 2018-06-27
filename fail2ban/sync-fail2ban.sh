#!/bin/bash

# updates the block list once daily. Make this file executable and place it in
#   /etc/cron.daily/sync-blocklist
#   
#  requires the ipset program, install it e.g. via
#  apt-get install ipset
# 
# inspired by https://gist.github.com/klepsydra/ecf975984b32b1c8291a
# but uses ipset because directly using iptables / ip6tables does not scale

PATH="/sbin:/bin:/usr/bin"

if test ! -x /sbin/ipset; then
  echo "ipset not installed"
  exit 1
fi

# sleep for up to 30 seconds to not overload blocklist.de on midnight
sleep $[ ( $RANDOM % 30 )  + 1 ]s

SET_TYPE="hash:ip"
SET_CONFIG="hashsize 16384 maxelem 131072"

# initialize the iptables integration if it is not already present
ipset -exist create blacklist-ip4 $SET_TYPE family inet $SET_CONFIG
ipset -exist create blacklist-ip6 $SET_TYPE family inet6 $SET_CONFIG
iptables -wn -L INPUT | fgrep -q 'match-set blacklist-ip4 src' || iptables -w -I INPUT -m set --match-set blacklist-ip4 src -j DROP
ip6tables -wn -L INPUT | fgrep -q 'match-set blacklist-ip6 src' || ip6tables -w -I INPUT -m set --match-set blacklist-ip6 src -j DROP

# create the new lists
ipset create new-blacklist-ip4 $SET_TYPE family inet $SET_CONFIG
ipset create new-blacklist-ip6 $SET_TYPE family inet6 $SET_CONFIG

# fill the new lists
#   this does the following:
#    1. get the file https://lists.blocklist.de/lists/all.txt
#    2. stream every line to the grep command that finds lines 
#       that only have a IPv4 or IPv6 address on them (actually something 
#       like 999.999.999.999 will match, too but we do not mind) to filter out 
#       comments and shell injection attacks
#    3. removes duplicate IP addresses
#    4. prefixes "add new-blacklist-ip6" or "add new-blacklist-ip4" to the line
#       depending on wheter there is a : in the line (IPv6 addresses always have one)
#    5. feed these to ipset in one single call
curl -s https://lists.blocklist.de/lists/all.txt \
  | grep -Pxe '((?:[0-9]{1,3}\.){3}[0-9]{1,3}|(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])))' \
  | sort -u \
  | awk '/:/{ print "add new-blacklist-ip6 " $0 } !/:/{ print "add new-blacklist-ip4 " $0 }' \
  | ipset restore

# swap the new and the old lists
ipset swap blacklist-ip4 new-blacklist-ip4
ipset swap blacklist-ip6 new-blacklist-ip6


# remove the old lists (they have the new lists names now)
ipset destroy new-blacklist-ip4
ipset destroy new-blacklist-ip6
