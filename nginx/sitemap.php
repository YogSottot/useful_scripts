<?php
/* RewriteRule ^sitemap\.xml$ /sitemap.php [L] */
require($_SERVER["DOCUMENT_ROOT"]."/bitrix/modules/main/include/prolog_before.php");

$sitemap = new \sitemap\Sitemap();

header('Content-Type: application/xml');

/* @var $urls */
/* @var $host */

echo '<?xml version="1.0" encoding="UTF-8"?>';
?>
<urlset xmlns="https://www.sitemaps.org/schemas/sitemap/0.9"><?
        foreach ($sitemap->getUrls() as $url)
        {
                ?>
                <url>
                <loc><?= $url['loc'] ?></loc>
                <changefreq><?= $url['changefreq'] ?></changefreq>
                <priority><?= (empty($url['priority']) ? '0.5' : $url['priority']) ?></priority>
                <lastmod><?= $url['lastmod'] ?></lastmod>
                </url><?
        }
        ?></urlset>
