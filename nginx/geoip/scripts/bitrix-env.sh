#!/usr/bin/env bash
set -Eeuo pipefail

# Installer for BitrixEnv nginx GeoIP2 filtering.
BASE_URL='https://raw.githubusercontent.com/YogSottot/useful_scripts/master/nginx/geoip'
CRON_FILE='/etc/cron.d/nginx-geo-updates'

if (( EUID != 0 )); then
    echo 'ERROR: run as root' >&2
    exit 1
fi

for cmd in curl nginx mktemp install cp cmp flock; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: missing command: $cmd" >&2; exit 1; }
done

exec 9>/run/bitrix-env-geo-install.lock
flock -n 9 || { echo 'ERROR: another installation is in progress' >&2; exit 1; }

workdir=$(mktemp -d)
declare -a urls=(
    "$BASE_URL/nginx/geoip/configs/geo-filter.conf"
    "$BASE_URL/nginx/geoip/configs/geo-block.conf"
    "$BASE_URL/scripts/update-geolite2.sh"
    "$BASE_URL/scripts/update-googlebot-ips.sh"
    "$BASE_URL/scripts/update-yandex-ips.sh"
)
declare -a destinations=(
    '/etc/nginx/bx/maps/geo-filter.conf'
    '/etc/nginx/bx/site_settings/default/geo-block.conf'
    '/usr/local/sbin/update-geolite2.sh'
    '/usr/local/sbin/update-googlebot-ips.sh'
    '/usr/local/sbin/update-yandex-ips.sh'
)
declare -a modes=(0644 0644 0755 0755 0755)
declare -a changed=()

rollback() {
    local index dst
    for index in "${changed[@]}"; do
        dst=${destinations[index]}
        if [[ -f "$workdir/backup-$index" ]]; then
            cp -p -- "$workdir/backup-$index" "$dst"
        else
            rm -f -- "$dst"
        fi
    done
    if [[ -f "$workdir/backup-cron" ]]; then
        cp -p -- "$workdir/backup-cron" "$CRON_FILE"
    elif [[ -f "$workdir/cron-installed" ]]; then
        rm -f -- "$CRON_FILE"
    fi
}
cleanup() { rm -rf -- "$workdir"; }
trap cleanup EXIT

# Download all files before touching installed configuration.
for i in "${!urls[@]}"; do
    echo "Downloading: ${urls[i]}"
    curl --fail --location --silent --show-error \
        --retry 3 --connect-timeout 15 --max-time 120 \
        --output "$workdir/file-$i" "${urls[i]}"
    [[ -s "$workdir/file-$i" ]] || { echo "ERROR: empty download: ${urls[i]}" >&2; exit 1; }
    if (( i >= 2 )); then
        bash -n "$workdir/file-$i"
    fi
done

cat > "$workdir/cron" <<'CRON'
# Update GeoLite2 country database (compatible with nginx GeoIP2 auto_reload)
0 1 * * * root /usr/local/sbin/update-geolite2.sh >> /var/log/update-geolite2.log 2>&1

# Update Google crawler CIDR ranges
3 1 * * * root /usr/local/sbin/update-googlebot-ips.sh >> /var/log/update-googlebot-ips.log 2>&1

# Update Yandex CIDR ranges
5 1 * * * root /usr/local/sbin/update-yandex-ips.sh >> /var/log/update-yandex-ips.log 2>&1
CRON

# Install. Keep previous versions for rollback if nginx config check fails.
for i in "${!destinations[@]}"; do
    dst=${destinations[i]}
    install -d -m 0755 -- "$(dirname "$dst")"
    if [[ -f "$dst" ]]; then
        cp -p -- "$dst" "$workdir/backup-$i"
    fi
    install -m "${modes[i]}" -- "$workdir/file-$i" "$dst"
    changed+=("$i")
    echo "Installed: $dst"
done

if [[ -f "$CRON_FILE" ]]; then
    cp -p -- "$CRON_FILE" "$workdir/backup-cron"
fi
install -m 0644 -- "$workdir/cron" "$CRON_FILE"
touch "$workdir/cron-installed"

if ! nginx -t; then
    echo 'ERROR: nginx -t failed. Rolling back installed files.' >&2
    rollback
    exit 1
fi

echo 'Installation finished. nginx -t succeeded.'
echo 'Nginx was not reloaded; use systemctl reload nginx after checking configuration.'
echo 'Note: initial GeoIP database and crawler CIDR files must exist if nginx config includes them.'
