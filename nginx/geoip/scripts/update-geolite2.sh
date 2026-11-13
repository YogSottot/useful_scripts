
#!/usr/bin/env bash
set -Eeuo pipefail

URL="https://github.com/wp-statistics/GeoLite2-Country/raw/refs/heads/master/GeoLite2-Country.mmdb.gz"

DEST="/usr/share/GeoIP/GeoLite2-Country.mmdb"
DIR=$(dirname "$DEST")

mkdir -p "$DIR"

# Исключаем параллельные запуски
exec 9>/run/update-geolite2.lock
flock -n 9 || exit 0

TMP=$(mktemp -d "$DIR/.geolite2.XXXXXXXX")
trap 'rm -rf "$TMP"' EXIT

echo "Downloading GeoLite2-Country..."

curl -fLsS \
    --retry 3 \
    --connect-timeout 15 \
    --max-time 120 \
    "$URL" -o "$TMP/database.gz"

# Проверка gzip
gzip -t "$TMP/database.gz"

# Распаковка
gzip -dc "$TMP/database.gz" > "$TMP/database.mmdb"

# Минимальный размер
test "$(stat -c %s "$TMP/database.mmdb")" -gt 100000

# Проверка сигнатуры метаданных MMDB
python3 - "$TMP/database.mmdb" <<'PY'
import sys

marker = b"\xab\xcd\xefMaxMind.com"

with open(sys.argv[1], "rb") as f:
    f.seek(0, 2)
    size = f.tell()
    f.seek(max(0, size - 131072))
    assert marker in f.read(), "Invalid MMDB metadata marker"
PY

# Проверка изменений
if [[ -f "$DEST" ]] && cmp -s "$TMP/database.mmdb" "$DEST"; then
    echo "Database unchanged"
    exit 0
fi

# Сохраняем предыдущую версию
if [[ -f "$DEST" ]]; then
    cp -a "$DEST" "$TMP/previous.mmdb"
fi

install -m 0644 "$TMP/database.mmdb" "$TMP/new.mmdb"
mv -f "$TMP/new.mmdb" "$DEST"

# Проверяем конфигурацию
if ! nginx -t; then
    echo "nginx -t failed, rolling back" >&2

    if [[ -f "$TMP/previous.mmdb" ]]; then
        mv -f "$TMP/previous.mmdb" "$DEST"
    else
        rm -f "$DEST"
    fi

    exit 1
fi

# Применяем изменения
if ! systemctl reload nginx; then
    echo "Nginx reload failed, rolling back database" >&2

    if [[ -f "$TMP/previous.mmdb" ]]; then
        mv -f "$TMP/previous.mmdb" "$DEST"
    else
        rm -f "$DEST"
    fi

    systemctl reload nginx || true
    exit 1
fi

echo "GeoLite2-Country updated successfully"
