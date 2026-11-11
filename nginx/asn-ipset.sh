#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "Usage: $0 AS123 [AS456 ...]"
  exit 1
fi

for ASN in "$@"; do
  if [[ ! "$ASN" =~ ^AS[0-9]+$ ]]; then
    echo "Invalid ASN: $ASN" >&2
    continue
  fi

  num="${ASN#AS}"
  url="https://asn.ipinfo.app/api/text/ipset/${ASN}"
  out=$(mktemp)

  echo "Fetching ${ASN} -> ${url}"

  if ! wget \
    --quiet \
    --tries=3 \
    --timeout=10 \
    --waitretry=2 \
    "$url" -O "$out"; then
    echo "Failed: ${ASN}" >&2
    rm -f "$out"
    continue
  fi

  if [ ! -s "$out" ]; then
    echo "Empty file for ${ASN}" >&2
    rm -f "$out"
    continue
  fi

  # Allow existing sets and entries
  sed -i \
    -e 's/^ipset -N /ipset -exist -N /' \
    -e 's/^ipset -A /ipset -exist -A /' \
    "$out"

  # Create and populate ipsets
  if ! bash "$out"; then
    echo "Failed to populate ipsets for ${ASN}" >&2
    rm -f "$out"
    continue
  fi

  rm -f "$out"

  # IPv4
  set4="${num}-4"

  if ipset list -n | grep -Fxq "$set4"; then
    if ! iptables -C INPUT -m set --match-set "$set4" src -j DROP 2>/dev/null; then
      iptables -I INPUT 1 -m set --match-set "$set4" src -j DROP
      echo "Added IPv4 DROP: $set4"
    fi
  fi

  # IPv6
  set6="${num}-6"

  if command -v ip6tables >/dev/null 2>&1 &&
     ipset list -n | grep -Fxq "$set6"; then

    if ! ip6tables -C INPUT -m set --match-set "$set6" src -j DROP 2>/dev/null; then
      ip6tables -I INPUT 1 -m set --match-set "$set6" src -j DROP
      echo "Added IPv6 DROP: $set6"
    fi
  fi
done

# Save firewall configuration
echo "Saving ipset and iptables rules..."

ipset save > /etc/sysconfig/ipset
iptables-save > /etc/sysconfig/iptables

if command -v ip6tables-save >/dev/null 2>&1; then
  ip6tables-save > /etc/sysconfig/ip6tables
fi

echo "Done."
