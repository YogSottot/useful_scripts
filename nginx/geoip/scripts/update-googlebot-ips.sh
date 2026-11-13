#!/usr/bin/env bash
set -euo pipefail

URL="https://developers.google.com/static/crawling/ipranges/common-crawlers.json"
DEST="/etc/nginx/googlebot-ips.conf"

TMP=$(mktemp)
trap 'rm -f "$TMP" "${TMP}.new"' EXIT

curl -fsSL --retry 3 "$URL" -o "$TMP"

jq -er '
  [.prefixes[] | (.ipv4Prefix // .ipv6Prefix // empty)]
  | if length > 0 then .[] + " 1;" else error("Empty IP list") end
' "$TMP" > "${TMP}.new"

# Если список не изменился, ничего не делаем
if cmp -s "${TMP}.new" "$DEST"; then
    exit 0
fi

install -m 0644 "${TMP}.new" "$DEST"

if nginx -t; then
    systemctl reload nginx
else
    echo "Nginx configuration test failed" >&2
    exit 1
fi
