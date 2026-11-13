# GeoIP-фильтрация в Nginx (AlmaLinux 9)

Фильтрация HTTP(S)-запросов по стране с помощью **Nginx + GeoIP2 (MaxMind DB)** и исключений для поисковых роботов по проверенным IP-диапазонам.

Проект рассчитан на **AlmaLinux 9** и системный **Nginx 1.26.3**. Версия Nginx приведена как исходная конфигурация, а не как гарантия совместимости любого стороннего модуля.

## Возможности

- Разрешение доступа только из указанных стран (`RU`, `BY`, `KZ` в примере).
- Исключения из геоблокировки для IP поисковых роботов, в том числе из стран вне белого списка.
- Автоматическое обновление базы `GeoLite2-Country.mmdb` из [wp-statistics/GeoLite2-Country](https://github.com/wp-statistics/GeoLite2-Country).
- Обновление сетей Google из официального JSON; при необходимости — сетей Яндекса.
- Проверка получаемых данных перед заменой рабочих файлов.

> **Важно:** GeoIP2 нужен для определения страны. Директива `geo` в Nginx встроенная и отдельного GeoIP-модуля не требует. Не путайте старый `ngx_http_geoip_module` (GeoIP Legacy `.dat`) с `ngx_http_geoip2_module` (MMDB).

## Пример структуры репозитория

```text
.
├── README.md
├── scripts/
│   ├── update-geolite2.sh
│   ├── update-googlebot-ips.sh
│   └── update-yandex-ips.sh
└── configs/
    ├── geo-filter.conf              # контекст http {}
    └── geo-block.conf            # фрагмент server {}
```

Имена в примере условные: при копировании своих файлов согласуйте пути в README и конфигурации.

## 1. Требования

- AlmaLinux 9, Nginx с подключённым и **совместимым** `ngx_http_geoip2_module`.
- `curl`, `gzip`, `python3`, `util-linux` (`flock`), `jq` — для соответствующих скриптов.
- Права `root` для обновления файлов в `/usr/share/GeoIP/` и `/etc/nginx/`.

```bash
dnf install -y curl gzip python3 util-linux jq
nginx -V 2>&1
nginx -t
```

Модуль GeoIP2 **не входит в стандартный Nginx во всех сборках AlmaLinux 9**. Проверьте его наличие и загрузку отдельно. При самостоятельной сборке динамического модуля используйте параметры сборки, совместимые с установленным Nginx (`--with-compat` само по себе не гарантирует совместимость), либо собирайте RPM под конкретную сборку Nginx. Не заменяйте системный Nginx сторонним пакетом без проверки зависимостей.

Исходники модуля: [leev/ngx_http_geoip2_module](https://github.com/leev/ngx_http_geoip2_module).  
После установки модуля убедитесь, что он подключен. Например добавить строку перед `events` в `nginx.conf`

```txt
load_module "/usr/lib64/nginx/modules/ngx_http_geoip2_module.so";

```

## 2. База GeoLite2-Country

Источник:

```text
https://github.com/wp-statistics/GeoLite2-Country/raw/refs/heads/master/GeoLite2-Country.mmdb.gz
```

Целевой путь:

```text
/usr/share/GeoIP/GeoLite2-Country.mmdb
```

Скопируйте `scripts/update-geolite2.sh` в `/usr/local/sbin/` и запустите:

```bash
install -m 0755 scripts/update-geolite2.sh /usr/local/sbin/update-geolite2.sh
/usr/local/sbin/update-geolite2.sh
```

Скрипт из этой задачи скачивает `.mmdb.gz`, проверяет gzip, минимальный размер и сигнатуру метаданных MMDB, сравнивает базу с текущей, атомарно заменяет файл и при настройке без `auto_reload` проверяет Nginx и выполняет reload с откатом при ошибке.

**Ограничение проверки:** сигнатура и размер не доказывают корректность всей базы или подлинность источника. Для более строгой проверки используйте `mmdblookup`/библиотеку `libmaxminddb` и проверку происхождения файла. Репозиторий wp-statistics — сторонняя публикация базы, а не официальный endpoint MaxMind; проверьте лицензионные условия и атрибуцию для своей публикации/развёртывания.

### `auto_reload` или `systemctl reload nginx`?

Модуль GeoIP2 поддерживает:

```nginx
geoip2 /usr/share/GeoIP/GeoLite2-Country.mmdb {
    auto_reload 5m;
    $country_code country iso_code;
}
```

При `auto_reload` Nginx периодически проверяет изменение файла MMDB. Тогда скрипту **не нужно** делать `systemctl reload nginx`; достаточно корректной проверки и атомарной замены базы. Если `auto_reload` не используется, скрипт должен проверять конфигурацию и перезагружать Nginx. Выберите **один** режим и согласуйте его с содержимым скрипта.

## 3. Конфигурация Nginx

Пример для контекста `http {}` (например, `/etc/nginx/conf.d/geo-filter.conf` или `/etc/nginx/bx/maps/geo-filter.conf`):

```nginx
geoip2 /usr/share/GeoIP/GeoLite2-Country.mmdb {
    auto_reload 5m;
    $country_code country iso_code;
}

map $country_code $country_allowed {
    default 0;
    RU 1;
    BY 1;
    KZ 1;
}

geo $bot_allowed {
    default 0;
    include /etc/nginx/googlebot-ips.conf;
    include /etc/nginx/yandex-ips.conf;
}

map "$country_allowed:$bot_allowed" $geo_block {
    "0:0" 1;
    default 0;
}
```

> Файлы `googlebot-ips.conf` и `yandex-ips.conf` должны содержать строки вида `203.0.113.0/24 1;` — это **пример синтаксиса**, а не реальный диапазон. Создайте их **до** проверки конфигурации (`nginx -t`), даже если пока пустыми. Для IPv6 нужен Nginx с поддержкой IPv6.

Внутри нужного `server {}`:

```nginx
if ($geo_block) {
    return 403;
}
```

`if` с одним `return` в `server` допустим. Проверьте, где это правило размещено относительно других директив и `location`.

**Если Nginx находится за reverse proxy/CDN:** сперва корректно настройте `set_real_ip_from`, `real_ip_header` и при необходимости `real_ip_recursive`. Доверять заголовку `X-Forwarded-For` от любого клиента **нельзя**: иначе геофильтр обходится подменой заголовка.

## 4. Разрешение Googlebot

Официальный список обычных поисковых роботов Google:

```text
https://developers.google.com/crawling/ipranges/common-crawlers.json
```

В 2026 году Google перенёс файлы из `/search/apis/ipranges/` в `/crawling/ipranges/`. Используйте новый адрес.

Пример преобразования JSON в формат `geo`:

```bash
curl -fsSL 'https://developers.google.com/crawling/ipranges/common-crawlers.json' |
  jq -er '.prefixes | if length > 0 then .[] | (.ipv4Prefix // .ipv6Prefix // empty) + " 1;" else error("empty prefixes") end'
```

Для production **не перенаправляйте вывод сразу** в активный `/etc/nginx/googlebot-ips.conf`: скачивайте во временный файл, проверяйте список, затем заменяйте файл и делайте `nginx -t && systemctl reload nginx`. В отличие от MMDB, для `geo include` нет `auto_reload`: новый список начинает применяться после reload Nginx.

`common-crawlers.json` содержит сети категории *common crawlers*. Если нужны AdsBot или другие категории, изучите также [special crawlers](https://developers.google.com/crawling/docs/crawlers-fetchers/overview-google-crawlers) и их отдельные списки.

## 5. Яндекс: важное ограничение

Официальная страница: <https://yandex.ru/ips>.

Она публикует **диапазоны IP, используемых Яндексом**, а не гарантированный эксклюзивный список IP `YandexBot`. Разрешив все эти сети, вы пропустите через геофильтр не только поискового робота, но и прочие запросы с IP из сетей Яндекса.

Простой `curl | grep CIDR` может не работать: IP-адреса не обязательно представлены в сыром HTML как текстовые CIDR. Для точного выделения робота можно проверять обратный DNS с последующей прямой проверкой адреса; это лучше выполнять вне пути обработки HTTP-запроса (например, для создания доверенного списка), с учётом кеширования и срока актуальности.

Использование одного `User-Agent: YandexBot` или `Googlebot` для обхода геоблокировки **небезопасно**, так как User-Agent подделывается.

## 6. Автоматизация

Пример `/etc/cron.d/nginx-geo-updates`:

```cron
# Обновление базы стран; скрипт должен соответствовать режиму auto_reload
0 1 * * * root /usr/local/sbin/update-geolite2.sh >> /var/log/update-geolite2.log 2>&1

# Обновление Google CIDR; после успешного изменения нужен nginx reload
3 1 * * * root /usr/local/sbin/update-googlebot-ips.sh >> /var/log/update-googlebot-ips.log 2>&1

# Обновление Yandex CIDR;
5 1 * * * root /usr/local/sbin/update-yandex-ips.sh >> /var/log/update-yandex-ips.log 2>&1

```

Каждому скрипту необходимы блокировка параллельного запуска, проверка корректности и работа через временные файлы.

## 7. Проверка

```bash
nginx -t
systemctl status nginx --no-pager
ls -lh /usr/share/GeoIP/GeoLite2-Country.mmdb
ls -lh /etc/nginx/googlebot-ips.conf
```

Для отладки можно временно добавить заголовки в тестовый `server` (не оставлять в production, если раскрытие правил нежелательно):

```nginx
add_header X-Geo-Country "$country_code" always;
add_header X-Geo-Blocked "$geo_block" always;
```

И проверить:

```bash
curl -Ik https://example.com/
```

Тестировать разрешение роботов нужно с **реального IP из официального списка**, а не путём подстановки `User-Agent`. При добавлении IP в исключения проверяйте и IPv4, и IPv6.

## 8. Безопасность и эксплуатация

- GeoIP неточен: VPN, мобильные сети, прокси и смена принадлежности IP дают ложные срабатывания.
- При отсутствии страны (`$country_code` пуст) пример конфигурации блокирует запрос, если IP не в исключениях.
- `403` для Googlebot или других роботов может привести к проблемам с обходом и индексацией: контролируйте access/error logs и Search Console.
- Режим *fail-closed*: при сбое загрузки обновления **сохраняйте последнюю рабочую базу и CIDR-списки**, не затирайте их пустыми файлами.
- Доверенный CIDR Google подтверждает происхождение из опубликованного диапазона, но не конкретный `User-Agent`; если принципиально нужно разрешить только Googlebot, добавьте условие `User-Agent` **в дополнение к проверке IP**, а не вместо неё.
- После обновления Nginx проверьте ABI-совместимость стороннего динамического модуля GeoIP2.

## Ссылки

- [ngx_http_geoip2_module](https://github.com/leev/ngx_http_geoip2_module)
- [GeoLite2-Country (wp-statistics)](https://github.com/wp-statistics/GeoLite2-Country)
- [Google: новые пути к диапазонам роботов](https://developers.google.com/search/blog/2026/03/crawler-ip-ranges)
- [Google: проверка поисковых роботов](https://developers.google.com/crawling/docs/crawlers-fetchers/verify-google-requests)
- [IP-диапазоны Яндекса](https://yandex.ru/ips)

## Лицензии

Скрипты и конфигурации, добавляемые в этот репозиторий, лицензируйте отдельно по своему выбору. Лицензия проекта **не заменяет** лицензии и условия использования GeoLite2, MaxMind и сторонних источников данных.
