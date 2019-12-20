<?php
//$fileContent = file_get_contents($_REQUEST['file']);
$fileContent = file_get_contents($_SERVER['DOCUMENT_ROOT'] . $_SERVER['REQUEST_URI']);

//if (isset($_REQUEST['domain'])) {
        //$subDomain = $_REQUEST['domain'];
          $subDomain = array_shift((explode('.', $_SERVER['HTTP_HOST'])));
    $domain = str_replace($subDomain . '.', '', $_SERVER['SERVER_NAME']);

        $protocol = array('http://', 'https://');
        foreach($protocol as $p) {
                $fileContent = str_replace($p . $domain, 'https://' . $subDomain . '.' . $domain, $fileContent);
                $fileContent = str_replace($p . 'www.' . $domain, 'https://' . $subDomain . '.' . $domain, $fileContent);
        }
//}
header("Content-type: text/xml");
echo $fileContent;

/*
https://stackoverflow.com/questions/5292937/php-function-to-get-the-subdomain-of-a-url
put in nginx, works only with php-fpm
location ^~ /sitemap {
    rewrite ^/sitemap(.*)\.xml /sm_gen.php last;
}
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/nginx/sm_gen.php
*/
