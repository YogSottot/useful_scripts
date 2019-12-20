<?php
/*
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/nginx/robots.php
put in nginx
location = /robots.txt {
    rewrite ^/robots.txt  /robots.php last;
}
*/
$host = $_SERVER["HTTP_HOST"];
$host = preg_replace("/\:\d+/is", "", $host);
if (isset($_SERVER["HTTPS"]) && $_SERVER["HTTPS"] == "on"){
    $http = "https";
}
else{
    $http = "http";
}
header("Content-Type: text/plain");?># main
User-Agent: Yandex
Disallow: /*?
Disallow: /*&
Disallow: /*%
Disallow: /*=
Disallow: /*clear
Disallow: */index.php
Disallow: /bitrix/
Disallow: /*ORDER_BY
Disallow: /personal/
Disallow: /partners/
Disallow: /payment/
Disallow: /reviews/
Disallow: /franchising/
Disallow: /bonus-program/
Disallow: /faq/
Disallow: /bitrix/rk.php
Disallow: *bitrix_*=
Disallow: /*PAGEN
Disallow: *captcha                                     
Allow: /bitrix/components/
Allow: /bitrix/cache/
Allow: /bitrix/js/
Allow: /bitrix/templates/
Allow: /bitrix/panel/
Allow: *.js*
Allow: *.css*
Allow: /upload/*.jpg
Allow: /upload/*.jpeg
Allow: /upload/*.png
Allow: /upload/*.gif

User-Agent: Googlebot
Disallow: /*?
Disallow: /*&
Disallow: /*%
Disallow: /*=
Disallow: /*clear
Disallow: */index.php
Disallow: /bitrix/
Disallow: /*ORDER_BY
Disallow: /personal/
Disallow: /partners/
Disallow: /payment/
Disallow: /reviews/
Disallow: /franchising/
Disallow: /bonus-program/
Disallow: /faq/
Disallow: /bitrix/rk.php
Disallow: *bitrix_*=
Disallow: /*PAGEN
Disallow: *captcha                                     
Allow: /bitrix/components/
Allow: /bitrix/cache/
Allow: /bitrix/js/
Allow: /bitrix/templates/
Allow: /bitrix/panel/
Allow: *.js*
Allow: *.css*
Allow: /upload/*.jpg
Allow: /upload/*.jpeg
Allow: /upload/*.png
Allow: /upload/*.gif

User-Agent: Mail.Ru
Disallow: /*?
Disallow: /*&
Disallow: /*%
Disallow: /*=
Disallow: /*clear
Disallow: */index.php
Disallow: /bitrix/
Disallow: /*ORDER_BY
Disallow: /personal/
Disallow: /partners/
Disallow: /payment/
Disallow: /reviews/
Disallow: /franchising/
Disallow: /bonus-program/
Disallow: /faq/
Disallow: /bitrix/rk.php
Disallow: *bitrix_*=
Disallow: /*PAGEN
Disallow: *captcha                                     
Allow: /bitrix/components/
Allow: /bitrix/cache/
Allow: /bitrix/js/
Allow: /bitrix/templates/
Allow: /bitrix/panel/
Allow: *.js*
Allow: *.css*
Allow: /upload/*.jpg
Allow: /upload/*.jpeg
Allow: /upload/*.png
Allow: /upload/*.gif
Crawl-delay: 3

User-Agent: Bingbot
Disallow: /*?
Disallow: /*&
Disallow: /*%
Disallow: /*=
Disallow: /*clear
Disallow: */index.php
Disallow: /bitrix/
Disallow: /*ORDER_BY
Disallow: /personal/
Disallow: /partners/
Disallow: /payment/
Disallow: /reviews/
Disallow: /franchising/
Disallow: /bonus-program/
Disallow: /faq/
Disallow: /bitrix/rk.php
Disallow: *bitrix_*=
Disallow: /*PAGEN
Disallow: *captcha                                     
Allow: /bitrix/components/
Allow: /bitrix/cache/
Allow: /bitrix/js/
Allow: /bitrix/templates/
Allow: /bitrix/panel/
Allow: *.js*
Allow: *.css*
Allow: /upload/*.jpg
Allow: /upload/*.jpeg
Allow: /upload/*.png
Allow: /upload/*.gif
Crawl-delay: 5

User-Agent: *
Disallow: /*?
Disallow: /*&
Disallow: /*%
Disallow: /*=
Disallow: /*clear
Disallow: */index.php
Disallow: /bitrix/
Disallow: /*ORDER_BY
Disallow: /personal/
Disallow: /partners/
Disallow: /payment/
Disallow: /reviews/
Disallow: /franchising/
Disallow: /bonus-program/
Disallow: /faq/
Disallow: /bitrix/rk.php
Disallow: *bitrix_*=
Disallow: /*PAGEN
Disallow: *captcha                                     
Allow: /bitrix/components/
Allow: /bitrix/cache/
Allow: /bitrix/js/
Allow: /bitrix/templates/
Allow: /bitrix/panel/
Allow: *.js*
Allow: *.css*
Allow: /upload/*.jpg
Allow: /upload/*.jpeg
Allow: /upload/*.png
Allow: /upload/*.gif

Host: <?=$http?>://<?=$host.PHP_EOL;?>
Sitemap: <?=$http?>://<?=$host;?>/sitemap.xml
