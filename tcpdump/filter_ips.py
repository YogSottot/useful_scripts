#!/usr/bin/env python

import ipaddress
import sys

def load_subnets(filename):
    with open(filename, 'r') as f:
        return [ipaddress.ip_network(unicode(line.strip())) for line in f if line.strip()]

def is_ip_in_subnets(ip, subnets):
    try:
        # Remove colon if it's at the end of the IP
        ip = ip.rstrip(':')
        ip_obj = ipaddress.ip_address(unicode(ip))
        return any(ip_obj in subnet for subnet in subnets)
    except ValueError:
        return False

subnets = load_subnets('cloudflare_ips.txt')

for line in sys.stdin:
    parts = line.split()
    if len(parts) >= 2:
        ip = parts[-1]
        if not is_ip_in_subnets(ip, subnets):
            print(line.strip())
