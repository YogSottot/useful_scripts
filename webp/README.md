#### Генерация webp  

Помещаем оба файла в указанную директорию ```local/php_interface/include/classes/imageOptim/```
Добавляем в cron  

```bash
# optimization images to webp. 21.05.2020 Pakhomo D.S.
2 6 * * * /usr/bin/php -f /home/bitrix/www/bitrix/php_interface/include/classes/imageOptim/optimWebp.php >/dev/null 2>/home/bitrix/www/logs/optimWebp.log
# clean obsolete webp
7 5 * * 0 /home/bitrix/www/bitrix/php_interface/include/classes/imageOptim/wepb_cleaner.sh >/dev/null 2>/home/bitrix/www/logs/wepb_cleaner.log
```

Добавляем в nginx в ```/etc/nginx/bx/maps/webp.conf```  

```nginx
map $http_accept $webp_suffix {
    "~*webp" ".webp";
}

map $msie $cache_control {
    "1" "private";
}

map $msie $vary_header {
   default "Accept";
   "1" "";
}
```

Добавляем локацию в nginx в ```/etc/nginx/bx/site_settings/default/01_webp.conf```. Где ```default``` заменяем на нужный сайт, также меняем в скриптах пути к сайту.  

```nginx
location ~* ^(.+\.(png|jpg|jpeg))$ {
    add_header Vary $vary_header;
    add_header Cache-Control $cache_control;
    try_files $uri$webp_suffix $uri =404;
    expires max;
    break;
    access_log   off;
    log_not_found off;
    error_page 404 /404.html;
}
```
Создано на основе информации отсюда https://dev.1c-bitrix.ru/support/forum/forum32/topic115309/  

Или просто ставим этот модуль https://marketplace.1c-bitrix.ru/solutions/dev2fun.imagecompress/  
