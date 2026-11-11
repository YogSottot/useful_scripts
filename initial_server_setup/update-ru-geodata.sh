#!/usr/bin/env bash
set -euo pipefail

# 17 */6 * * * /usr/local/sbin/update-ru-geodata.sh > /var/log/update-ru-geodata.log 2>&1

PATH=/usr/sbin:/usr/bin:/sbin:/bin

GEOIP_URL="https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geoip.dat"
GEOSITE_URL="https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geosite.dat"

GEOIP_DST="/usr/local/x-ui/bin/geoip_RU.dat"
GEOSITE_DST="/usr/local/x-ui/bin/geosite_RU.dat"

TMP_DIR="$(mktemp -d)"
LOCK_FILE="/run/lock/update-ru-geodata.lock"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

exec 9>"$LOCK_FILE"
flock -n 9 || {
  echo "Another instance is already running"
  exit 0
}

download_file() {
  local url="$1"
  local dst_tmp="$2"

  curl -fL --connect-timeout 15 --max-time 300 \
    --retry 5 --retry-delay 3 --retry-all-errors \
    -o "$dst_tmp" "$url"

  [ -s "$dst_tmp" ] || {
    echo "Downloaded file is empty: $url" >&2
    exit 1
  }
}

install_if_changed() {
  local src="$1"
  local dst="$2"

  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    return 1
  fi

  install -m 0644 "$src" "$dst"
  return 0
}

main() {
  local changed=0

  mkdir -p "$(dirname "$GEOIP_DST")"

  download_file "$GEOIP_URL"   "$TMP_DIR/geoip.dat"
  download_file "$GEOSITE_URL" "$TMP_DIR/geosite.dat"

  install_if_changed "$TMP_DIR/geoip.dat" "$GEOIP_DST"   && changed=1 || true
  install_if_changed "$TMP_DIR/geosite.dat" "$GEOSITE_DST" && changed=1 || true

  if [ "$changed" -eq 1 ]; then
    systemctl reload x-ui
    echo "Updated geo files and reloaded x-ui"
  else
    echo "No changes"
  fi
}

main "$@"
