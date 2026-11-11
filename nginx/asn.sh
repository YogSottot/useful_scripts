#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "Usage: $0 ASN [ASN ...]"
  exit 1
fi

for ASN in "$@"; do
  url="https://asn.ipinfo.app/api/text/nginx/${ASN}"
  out="/etc/nginx/bx/settings/${ASN}.conf"

  echo "Fetching $ASN -> $out"

  wget \
    --quiet \
    --tries=3 \
    --timeout=10 \
    --waitretry=2 \
    "$url" -O "$out" || {
      echo "Failed: $ASN" >&2
      continue
    }

  # sanity check (пустые файлы — частая проблема)
  if [ ! -s "$out" ]; then
    echo "Empty file for $ASN, removing"
    rm -f "$out"
  fi
done

nginx -t && systemctl reload nginx
