<?php
$fileContent = file_get_contents($_SERVER['DOCUMENT_ROOT'] . $_SERVER['REQUEST_URI']);

if (isset($_REQUEST['domain'])) {
        $subDomain = $_REQUEST['domain'];
    $domain = str_replace($subDomain . '.', '', $_SERVER['SERVER_NAME']);

        $protocol = array('http://', 'https://');
        foreach($protocol as $p) {
                $fileContent = str_replace($p . $domain, 'https://' . $subDomain . '.' . $domain, $fileContent);
                $fileContent = str_replace($p . 'www.' . $domain, 'https://' . $subDomain . '.' . $domain, $fileContent);
        }
}
header("Content-type: text/xml");
echo $fileContent;

/*
put in .htaccess
  # dynamic map
  RewriteCond %{HTTP_HOST} ^([^.]+).domain\.(.+) [NC]
  RewriteRule ^sitemap(.*)\.xml /sitemap_gen.php?domain=%1 [NC,L]
*/
