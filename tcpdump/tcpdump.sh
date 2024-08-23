#!/bin/bash

INTERFACE="ens32"
DURATION=604800  # 7 days in seconds
OUTPUT_DIR="/home/bitrix/tcpdump"
FILE_SIZE=500  # Size in MB before rotating to a new file

mkdir -p $OUTPUT_DIR

tcpdump -i $INTERFACE 'not arp and not port 22' -G $DURATION -w "$OUTPUT_DIR/capture_%Y%m%d_%H%M%S.pcap" -C $FILE_SIZE -W 300

# We've added a FILE_SIZE variable set to 500 (MB), which you can adjust as needed.
# The -C $FILE_SIZE option tells tcpdump to create a new file once the current file reaches the specified size in millions of bytes.
# The -W 168 option limits the number of files created to 168 (which is 24 hours * 7 days, assuming a new file every hour).

# https://www.cloudflare.com/en-gb/ips/

# http filter
# 'tcp port 80 or tcp port 443' and '(tcp[((tcp[12:1] & 0xf0) >> 2):4] = 0x47455420 or tcp[((tcp[12:1] & 0xf0) >> 2):4] = 0x504F5354 or tcp[((tcp[12:1] & 0xf0) >> 2):4] = 0x48545450)'

# extract ips
# tcpdump -nr output.pcap | awk '{print $5}' | cut -d. -f1-4 | sort | uniq -c | sort -nr > ip_counts.txt

# sort by count
# grep -vE "ff02::2:|ff02::16:|ff02::1:3.hostmon:|Flags|ff02::1:ff00:1:|ff02::1:2.dhcpv6-server|is-at|Device-ID|ff02::fb.mdns:" ip_counts.txt | python filter_ips.py > filtered_ip_counts.txt

# capture only packets for specific ip
# tcpdump -i any -n -s0 -w capture.pcap dst <target_ip>
# tshark -r capture.pcap -Y "ip.dst == <target_ip>" -T fields -e data
