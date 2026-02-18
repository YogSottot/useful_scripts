<?php
//Для запуска необходимой карты укажите в адресе ее ID, пример:
//seo_sitemap_run.php?action=sitemap_run&ID=2&lang=ru
$_SERVER['DOCUMENT_ROOT'] = dirname(__FILE__, 4);

if ($argv) {
    unset($argv[0]);
    parse_str(join('&', $argv), $_REQUEST);
}

define('NO_KEEP_STATISTIC', true);
define('NOT_CHECK_PERMISSIONS', true);
define('NO_AGENT_STATISTIC', true);
define('STOP_STATISTICS', true);
define('BX_CRONTAB_SUPPORT', true);
define('LANGUAGE_ID', 'ru');

error_reporting(E_ERROR | E_WARNING | E_PARSE);
ini_set('display_errors', 1);
ini_set('memory_limit', '512M');

@set_time_limit(0);
@ignore_user_abort(true);

require_once($_SERVER['DOCUMENT_ROOT'] . "/bitrix/modules/main/include/prolog_admin_before.php");

define('ADMIN_MODULE_NAME', 'seo');

use Bitrix\Main;
use Bitrix\Main\IO;
use Bitrix\Main\SiteTable;
use Bitrix\Main\Localization\Loc;
use Bitrix\Seo\RobotsFile;
use Bitrix\Seo\SitemapTable;
use Bitrix\Seo\SitemapIndex;
use Bitrix\Seo\SitemapRuntime;
use Bitrix\Seo\SitemapRuntimeTable;

Loc::loadMessages($_SERVER['DOCUMENT_ROOT'] . '/bitrix/modules/seo/admin/seo_sitemap.php');

require_once('sitemap_custom.php');

/*if (!$USER->CanDoOperation('seo_tools'))
{
	$APPLICATION->AuthForm(Loc::getMessage("ACCESS_DENIED"));
}
*/

if (!Main\Loader::includeModule('seo')) {
    require($_SERVER["DOCUMENT_ROOT"] . "/bitrix/modules/main/include/prolog_admin_after.php");
    ShowError(Loc::getMessage("SEO_ERROR_NO_MODULE"));
    require($_SERVER["DOCUMENT_ROOT"] . "/bitrix/modules/main/include/epilog_admin.php");
}

$bIBlock = Main\Loader::includeModule('iblock');

$ID = intval($_REQUEST['ID']);

$arSitemap = null;
if ($ID > 0) {
    $dbSitemap = SitemapTable::getById($ID);
    $arSitemap = $dbSitemap->fetch();

    $dbSite = SiteTable::getByPrimary($arSitemap['SITE_ID']);
    $arSitemap['SITE'] = $dbSite->fetch();
}


if (!is_array($arSitemap)) {
    require($_SERVER["DOCUMENT_ROOT"] . "/bitrix/modules/main/include/prolog_admin_after.php");
    ShowError(Loc::getMessage("SEO_ERROR_SITEMAP_NOT_FOUND"));
    require($_SERVER["DOCUMENT_ROOT"] . "/bitrix/modules/main/include/epilog_admin.php");
} else {
    $arSitemap['SETTINGS'] = unserialize($arSitemap['SETTINGS']);

    $arSitemapSettings = [
        'SITE_ID' => $arSitemap['SITE_ID'],
        'PROTOCOL' => $arSitemap['SETTINGS']['PROTO'] == 1 ? 'https' : 'http',
        'DOMAIN' => $arSitemap['SETTINGS']['DOMAIN'],
    ];
}

/* аргументы: 
ID записи с настройками, 
массив с настройками, 
данные из b_seo_sitemap_runtime по текущей записи,
объект файла sitemap*/
function seoSitemapGetFilesData($PID, $arSitemap, $arCurrentDir, $sitemapFile)
{
    global $NS;

    $arDirList = [];

    if ($arCurrentDir['ACTIVE'] == SitemapRuntimeTable::ACTIVE) {
        $list = \CSeoUtils::getDirStructure(
            $arSitemap['SETTINGS']['logical'] == 'Y',
            $arSitemap['SITE_ID'],
            $arCurrentDir['ITEM_PATH']
        );

        foreach ($list as $dir) {
            $dirKey = "/" . ltrim($dir['DATA']['ABS_PATH'], "/");

            if ($dir['TYPE'] == 'F') {
                if (!isset($arSitemap['SETTINGS']['FILE'][$dirKey])
                    || $arSitemap['SETTINGS']['FILE'][$dirKey] == 'Y'
                ) {
                    if (preg_match($arSitemap['SETTINGS']['FILE_MASK_REGEXP'], $dir['FILE'])) {
                        $f = new IO\File($dir['DATA']['PATH'], $arSitemap['SITE_ID']);
                        $sitemapFile->addFileEntry($f);
                        $NS['files_count']++;
                    }
                }
            } else {
                if (!isset($arSitemap['SETTINGS']['DIR'][$dirKey])
                    || $arSitemap['SETTINGS']['DIR'][$dirKey] == 'Y'
                ) {
                    $arDirList[] = $dirKey;
                }
            }
        }
    } else {
        $len = strlen($arCurrentDir['ITEM_PATH']);
        if (!empty($arSitemap['SETTINGS']['DIR'])) {
            foreach ($arSitemap['SETTINGS']['DIR'] as $dirKey => $checked) {
                if ($checked == 'Y') {
                    if (strncmp($arCurrentDir['ITEM_PATH'], $dirKey, $len) === 0) {
                        $arDirList[] = $dirKey;
                    }
                }
            }
        }

        if (!empty($arSitemap['SETTINGS']['FILE'])) {
            foreach ($arSitemap['SETTINGS']['FILE'] as $dirKey => $checked) {
                if ($checked == 'Y') {
                    if (strncmp($arCurrentDir['ITEM_PATH'], $dirKey, $len) === 0) {
                        $fileName = IO\Path::combine(
                            SiteTable::getDocumentRoot($arSitemap['SITE_ID']),
                            $dirKey
                        );

                        if (!is_dir($fileName)) {
                            $f = new IO\File($fileName, $arSitemap['SITE_ID']);
                            if ($f->isExists()
                                && !$f->isSystem()
                                && preg_match($arSitemap['SETTINGS']['FILE_MASK_REGEXP'], $f->getName())
                            ) {
                                $sitemapFile->addFileEntry($f);
                                $NS['files_count']++;
                            }
                        }
                    }
                }
            }
        }
    }

    if (count($arDirList) > 0) {
        foreach ($arDirList as $dirKey) {
            $arRuntimeData = [
                'PID' => $PID,
                'ITEM_PATH' => $dirKey,
                'PROCESSED' => SitemapRuntimeTable::UNPROCESSED,
                'ACTIVE' => SitemapRuntimeTable::ACTIVE,
                'ITEM_TYPE' => SitemapRuntimeTable::ITEM_TYPE_DIR,
            ];
            SitemapRuntimeTable::add($arRuntimeData);
        }
    }

    SitemapRuntimeTable::update($arCurrentDir['ID'], [
        'PROCESSED' => SitemapRuntimeTable::PROCESSED,
    ]);
}//  end of seoSitemapGetFilesData


/*echo '<pre>';
print_r($arSitemap['SETTINGS']);
print_r($arSitemapSettings);
echo '</pre>';

die();*/

if ($_REQUEST['action'] == 'sitemap_run') // && check_bitrix_sessid()
{
    $arValueSteps = [
        'init' => 0,
        'init1' => 1,
        'files' => 40,
        'iblock_index' => 50,
        'iblock' => 60,
        'forum_index' => 70,
        'forum' => 80,
        'index' => 100,
    ];

    $PID = $ID;

    foreach ($arValueSteps as $key => $v) {

        if ($v == $arValueSteps['init']) {
            SitemapRuntimeTable::clearByPid($PID);

            $NS['time_start'] = microtime(true);
            $NS['files_count'] = 0;
            $NS['steps_count'] = 0;

            $bRootChecked = isset($arSitemap['SETTINGS']['DIR']['/'])
                && $arSitemap['SETTINGS']['DIR']['/'] == 'Y';

            $arRuntimeData = [
                'PID' => $PID,
                'ITEM_TYPE' => SitemapRuntimeTable::ITEM_TYPE_DIR,
                'ITEM_PATH' => '/',
                'PROCESSED' => SitemapRuntimeTable::UNPROCESSED,
                'ACTIVE' => $bRootChecked ? SitemapRuntimeTable::ACTIVE : SitemapRuntimeTable::INACTIVE,
            ];

            SitemapRuntimeTable::add($arRuntimeData);

            $msg = Loc::getMessage('SITEMAP_RUN_FILES', ['#PATH#' => '/']);

            $sitemapFile = new SitemapRuntimeCustom($PID, $arSitemap['SETTINGS']['FILENAME_FILES'], $arSitemapSettings);

            $v++;
        } elseif ($v < $arValueSteps['files']) {
            $NS['steps_count']++;

            $sitemapFile = new SitemapRuntimeCustom($PID, $arSitemap['SETTINGS']['FILENAME_FILES'], $arSitemapSettings);

            $stepDuration = 15;
            $ts_finish = microtime(true) + $stepDuration * 0.95;

            $bFinished = false;
            $bCheckFinished = false;

            $dbRes = null;

            while (!$bFinished && microtime(true) <= $ts_finish) {
                if (!$dbRes) {
                    $dbRes = SitemapRuntimeTable::getList([
                        'order' => ['ITEM_PATH' => 'ASC'],
                        'filter' => [
                            'PID' => $PID,
                            'ITEM_TYPE' => SitemapRuntimeTable::ITEM_TYPE_DIR,
                            'PROCESSED' => SitemapRuntimeTable::UNPROCESSED,
                        ],
                        'limit' => 1000,
                    ]);
                }

                if ($arRes = $dbRes->Fetch()) {
                    /* функция определена в текущем файле, аргументы:
                        $PID - ID записи с настройками,
                        $arSitemap - массив с настройками,
                        $arRes - данные из b_seo_sitemap_runtime по текущей записи,
                        $sitemapFile - объект файла sitemap*/
                    seoSitemapGetFilesData($PID, $arSitemap, $arRes, $sitemapFile);
                    $bCheckFinished = false;
                } elseif (!$bCheckFinished) {
                    $dbRes = null;
                    $bCheckFinished = true;
                } else {
                    $bFinished = true;
                }
            }
            if (!$bFinished) {
                if ($v < $arValueSteps['files'] - 1)
                    $v++;

                $msg = Loc::getMessage('SITEMAP_RUN_FILES', ['#PATH#' => $arRes['ITEM_PATH']]);
            } else {
                if (!is_array($NS['XML_FILES']))
                    $NS['XML_FILES'] = [];

                if ($sitemapFile->isNotEmpty()) {
                    if ($sitemapFile->isCurrentPartNotEmpty()) {
                        echo 'finish<br />';
                        $sitemapFile->finish();
                    } else {
                        $sitemapFile->delete();
                    }

                    $NS['XML_FILES'] = array_merge($NS['XML_FILES'], $sitemapFile->getNameList());
                } else {
                    $sitemapFile->delete();
                }

                $v = $arValueSteps['files'];
                $msg = Loc::getMessage('SITEMAP_RUN_FILE_COMPLETE', ['#FILE#' => $arSitemap['SETTINGS']['FILENAME_FILES']]);
            }

            //echo 'files '.$arValueSteps['files'];
            //die();
        } elseif ($v < $arValueSteps['iblock_index']) {
            $NS['time_start'] = microtime(true);

            $arIBlockList = [];
            if (Main\Loader::includeModule('iblock')) {
                $arIBlockList = $arSitemap['SETTINGS']['IBLOCK_ACTIVE'];
                if (count($arIBlockList) > 0) {
                    $arIBlocks = [];
                    $dbIBlock = CIBlock::GetList([], ['ID' => array_keys($arIBlockList)]);
                    while ($arIBlock = $dbIBlock->Fetch()) {
                        $arIBlocks[$arIBlock['ID']] = $arIBlock;
                    }

                    foreach ($arIBlockList as $iblockId => $iblockActive) {
                        if ($iblockActive !== 'Y' || !array_key_exists($iblockId, $arIBlocks)) {
                            unset($arIBlockList[$iblockId]);
                        } else {
                            SitemapRuntimeTable::add([
                                'PID' => $PID,
                                'PROCESSED' => SitemapRuntimeTable::UNPROCESSED,
                                'ITEM_ID' => $iblockId,
                                'ITEM_TYPE' => SitemapRuntimeTable::ITEM_TYPE_IBLOCK,
                            ]);

                            $fileName = str_replace(
                                ['#IBLOCK_ID#', '#IBLOCK_CODE#', '#IBLOCK_XML_ID#'],
                                [$iblockId, $arIBlocks[$iblockId]['CODE'], $arIBlocks[$iblockId]['XML_ID']],
                                $arSitemap['SETTINGS']['FILENAME_IBLOCK']
                            );

                            $sitemapFile = new SitemapRuntimeCustom($PID, $fileName, $arSitemapSettings);
                            if ($sitemapFile->isExists()) {
                                //$sitemapFile->delete();
                            }
                        }
                    }
                }
            }

            $NS['LEFT_MARGIN'] = 0;
            $NS['IBLOCK_LASTMOD'] = 0;

            $NS['IBLOCK'] = [];

            if (count($arIBlockList) <= 0) {
                $v = $arValueSteps['iblock'];
                $msg = Loc::getMessage('SITEMAP_RUN_IBLOCK_EMPTY');
            } else {
                $v = $arValueSteps['iblock_index'];
                $msg = Loc::getMessage('SITEMAP_RUN_IBLOCK');
            }
        } elseif ($v < $arValueSteps['iblock']) {
            $stepDuration = 300; //10
            $ts_finish = microtime(true) + $stepDuration * 0.95;

            $bFinished = false;
            $bCheckFinished = false;

            $currentIblock = false;
            $iblockId = 0;

            $dbOldIblockResult = null;
            $dbIblockResult = null;

            while (!$bFinished && microtime(true) <= $ts_finish) {
                if (!$currentIblock) {
                    $arCurrentIBlock = false;
                    $dbRes = SitemapRuntimeTable::getList([
                        'order' => ['ID' => 'ASC'],
                        'filter' => [
                            'PID' => $PID,
                            'ITEM_TYPE' => SitemapRuntimeTable::ITEM_TYPE_IBLOCK,
                            'PROCESSED' => SitemapRuntimeTable::UNPROCESSED,
                        ],
                        'limit' => 1,
                    ]);

                    $currentIblock = $dbRes->fetch();

                    if ($currentIblock) {
                        $iblockId = intval($currentIblock['ITEM_ID']);

                        $dbIBlock = CIBlock::GetByID($iblockId);
                        $arCurrentIBlock = $dbIBlock->Fetch();

                        if (!$arCurrentIBlock) {
                            SitemapRuntimeTable::update($currentIblock['ID'], [
                                'PROCESSED' => SitemapRuntimeTable::PROCESSED,
                            ]);

                            $NS['LEFT_MARGIN'] = 0;
                            $NS['IBLOCK_LASTMOD'] = 0;
                            $NS['LAST_ELEMENT_ID'] = 0;
                            unset($NS['CURRENT_SECTION']);
                        } else {
                            if (strlen($arCurrentIBlock['LIST_PAGE_URL']) <= 0)
                                $arSitemap['SETTINGS']['IBLOCK_LIST'][$iblockId] = 'N';
                            if (strlen($arCurrentIBlock['SECTION_PAGE_URL']) <= 0)
                                $arSitemap['SETTINGS']['IBLOCK_SECTION'][$iblockId] = 'N';
                            if (strlen($arCurrentIBlock['DETAIL_PAGE_URL']) <= 0)
                                $arSitemap['SETTINGS']['IBLOCK_ELEMENT'][$iblockId] = 'N';

                            $NS['IBLOCK_LASTMOD'] = max($NS['IBLOCK_LASTMOD'], MakeTimeStamp($arCurrentIBlock['TIMESTAMP_X']));

                            if ($NS['LEFT_MARGIN'] <= 0 && $arSitemap['SETTINGS']['IBLOCK_ELEMENT'][$iblockId] != 'N') {
                                $NS['CURRENT_SECTION'] = 0;
                            }

                            $fileName = str_replace(
                                ['#IBLOCK_ID#', '#IBLOCK_CODE#', '#IBLOCK_XML_ID#'],
                                [$iblockId, $arCurrentIBlock['CODE'], $arCurrentIBlock['XML_ID']],
                                $arSitemap['SETTINGS']['FILENAME_IBLOCK']
                            );
                            $sitemapFile = new SitemapRuntimeCustom($PID, $fileName, $arSitemapSettings);
                        }
                    }
                }

                if (!$currentIblock) {
                    $bFinished = true;
                } elseif (is_array($arCurrentIBlock)) {
                    if ($dbIblockResult == null) {
                        if (isset($NS['CURRENT_SECTION'])) {
                            $dbIblockResult = CIBlockElement::GetList(
                                ['ID' => 'ASC'],
                                [
                                    'IBLOCK_ID' => $iblockId,
                                    'ACTIVE' => 'Y',
                                    'SECTION_ID' => intval($NS['CURRENT_SECTION']),
                                    '>ID' => intval($NS['LAST_ELEMENT_ID']),
                                    'SITE_ID' => $arSitemap['SITE_ID'],
                                ],
                                false,
                                ['nTopCount' => 1000],
                                ['ID', 'TIMESTAMP_X', 'DETAIL_PAGE_URL']
                            );
                        } else {
                            $NS['LAST_ELEMENT_ID'] = 0;
                            $dbIblockResult = CIBlockSection::GetList(
                                ['LEFT_MARGIN' => 'ASC'],
                                [
                                    'IBLOCK_ID' => $iblockId,
                                    'GLOBAL_ACTIVE' => 'Y',
                                    '>LEFT_BORDER' => intval($NS['LEFT_MARGIN']),
                                ],
                                false,
                                [
                                    'ID', 'TIMESTAMP_X', 'SECTION_PAGE_URL', 'LEFT_MARGIN', 'IBLOCK_SECTION_ID',
                                ],
                                ['nTopCount' => 100]
                            );
                        }
                    }

                    if (isset($NS['CURRENT_SECTION'])) {
                        $arElement = $dbIblockResult->fetch();

                        if ($arElement) {
                            $arElement['LANG_DIR'] = $arSitemap['SITE']['DIR'];

                            $bCheckFinished = false;
                            $elementLastmod = MakeTimeStamp($arElement['TIMESTAMP_X']);
                            $NS['IBLOCK_LASTMOD'] = max($NS['IBLOCK_LASTMOD'], $elementLastmod);
                            $NS['LAST_ELEMENT_ID'] = $arElement['ID'];

                            $NS['IBLOCK'][$iblockId]['E']++;

                            $url = \CIBlock::ReplaceDetailUrl($arElement['DETAIL_PAGE_URL'], $arElement, false, "E");

                            $sitemapFile->addIBlockEntry($url, $elementLastmod);
                        } elseif (!$bCheckFinished) {
                            $bCheckFinished = true;
                            $dbIblockResult = null;
                        } else {
                            $bCheckFinished = false;
                            unset($NS['CURRENT_SECTION']);
                            $NS['LAST_ELEMENT_ID'] = 0;

                            $dbIblockResult = null;
                            if ($dbOldIblockResult) {
                                $dbIblockResult = $dbOldIblockResult;
                                $dbOldIblockResult = null;
                            }
                        }
                    } else {
                        $arSection = $dbIblockResult->fetch();

                        if ($arSection) {
                            $bCheckFinished = false;
                            $sectionLastmod = MakeTimeStamp($arSection['TIMESTAMP_X']);
                            $NS['LEFT_MARGIN'] = $arSection['LEFT_MARGIN'];
                            $NS['IBLOCK_LASTMOD'] = max($NS['IBLOCK_LASTMOD'], $sectionLastmod);

                            $bActive = false;
                            $bActiveElement = false;

                            if (isset($arSitemap['SETTINGS']['IBLOCK_SECTION_SECTION'][$iblockId][$arSection['ID']])) {
                                $bActive = $arSitemap['SETTINGS']['IBLOCK_SECTION_SECTION'][$iblockId][$arSection['ID']] == 'Y';
                                $bActiveElement = $arSitemap['SETTINGS']['IBLOCK_SECTION_ELEMENT'][$iblockId][$arSection['ID']] == 'Y';
                            } elseif ($arSection['IBLOCK_SECTION_ID'] > 0) {
                                $dbRes = SitemapRuntimeTable::getList([
                                    'filter' => [
                                        'PID' => $PID,
                                        'ITEM_TYPE' => SitemapRuntimeTable::ITEM_TYPE_SECTION,
                                        'ITEM_ID' => $arSection['IBLOCK_SECTION_ID'],
                                        'PROCESSED' => SitemapRuntimeTable::PROCESSED,
                                    ],
                                    'select' => ['ACTIVE', 'ACTIVE_ELEMENT'],
                                    'limit' => 1,
                                ]);

                                $parentSection = $dbRes->fetch();
                                if ($parentSection) {
                                    $bActive = $parentSection['ACTIVE'] == SitemapRuntimeTable::ACTIVE;
                                    $bActiveElement = $parentSection['ACTIVE_ELEMENT'] == SitemapRuntimeTable::ACTIVE;
                                }
                            } else {
                                $bActive = $arSitemap['SETTINGS']['IBLOCK_SECTION'][$iblockId] == 'Y';
                                $bActiveElement = $arSitemap['SETTINGS']['IBLOCK_ELEMENT'][$iblockId] == 'Y';
                            }

                            $arRuntimeData = [
                                'PID' => $PID,
                                'ITEM_ID' => $arSection['ID'],
                                'ITEM_TYPE' => SitemapRuntimeTable::ITEM_TYPE_SECTION,
                                'ACTIVE' => $bActive ? SitemapRuntimeTable::ACTIVE : SitemapRuntimeTable::INACTIVE,
                                'ACTIVE_ELEMENT' => $bActiveElement ? SitemapRuntimeTable::ACTIVE : SitemapRuntimeTable::INACTIVE,
                                'PROCESSED' => SitemapRuntimeTable::PROCESSED,
                            ];

                            if ($bActive) {
                                $NS['IBLOCK'][$iblockId]['S']++;

                                $arSection['LANG_DIR'] = $arSitemap['SITE']['DIR'];

                                $url = \CIBlock::ReplaceDetailUrl($arSection['SECTION_PAGE_URL'], $arSection, false, "S");

                                $sitemapFile->addIBlockEntry($url, $sectionLastmod);
                            }

                            SitemapRuntimeTable::add($arRuntimeData);

                            if ($bActiveElement) {
                                $NS['CURRENT_SECTION'] = $arSection['ID'];
                                $NS['LAST_ELEMENT_ID'] = 0;

                                $dbOldIblockResult = $dbIblockResult;
                                $dbIblockResult = null;
                            }
                        } elseif (!$bCheckFinished) {
                            unset($NS['CURRENT_SECTION']);
                            $bCheckFinished = true;
                            $dbIblockResult = null;
                        } else {
                            $bCheckFinished = false;
                            // we have finished current iblock

                            SitemapRuntimeTable::update($currentIblock['ID'], [
                                'PROCESSED' => SitemapRuntimeTable::PROCESSED,
                            ]);

                            if ($arSitemap['SETTINGS']['IBLOCK_LIST'][$iblockId] == 'Y' && strlen($arCurrentIBlock['LIST_PAGE_URL']) > 0) {
                                $NS['IBLOCK'][$iblockId]['I']++;

                                $arCurrentIBlock['IBLOCK_ID'] = $arCurrentIBlock['ID'];
                                $arCurrentIBlock['LANG_DIR'] = $arSitemap['SITE']['DIR'];

                                $url = \CIBlock::ReplaceDetailUrl($arCurrentIBlock['LIST_PAGE_URL'], $arCurrentIBlock, false, "");
                                $sitemapFile->addIBlockEntry($url, $NS['IBLOCK_LASTMOD']);
                            }

                            if ($sitemapFile->isNotEmpty()) {
                                if ($sitemapFile->isCurrentPartNotEmpty()) {
                                    $sitemapFile->finish();
                                } else {
                                    $sitemapFile->delete();
                                }

                                if (!is_array($NS['XML_FILES']))
                                    $NS['XML_FILES'] = [];

                                $NS['XML_FILES'] = array_merge($NS['XML_FILES'], $sitemapFile->getNameList());
                            } else {
                                $sitemapFile->delete();
                            }

                            $currentIblock = false;
                            $NS['LEFT_MARGIN'] = 0;
                            $NS['IBLOCK_LASTMOD'] = 0;
                            unset($NS['CURRENT_SECTION']);
                            $NS['LAST_ELEMENT_ID'] = 0;
                        }
                    }
                }
            }
            if ($v < $arValueSteps['iblock'] - 1) {
                $msg = Loc::getMessage('SITEMAP_RUN_IBLOCK_NAME', ['#IBLOCK_NAME#' => $arCurrentIBlock['NAME']]);
                $v++;
            }

            if ($bFinished) {
                $v = $arValueSteps['iblock'];
                $msg = Loc::getMessage('SITEMAP_RUN_FINALIZE');
            }
        } elseif ($v < $arValueSteps['forum_index']) {
            $NS['time_start'] = microtime(true);

            $arForumList = [];
            if (!empty($arSitemap['SETTINGS']['FORUM_ACTIVE'])) {
                foreach ($arSitemap['SETTINGS']['FORUM_ACTIVE'] as $forumId => $active) {
                    if ($active == "Y") {
                        $arForumList[$forumId] = "Y";
                    }
                }
            }
            if (count($arForumList) > 0 && Main\Loader::includeModule('forum')) {
                $arForums = [];
                $db_res = CForumNew::GetListEx(
                    [],
                    [
                        '@ID' => array_keys($arForumList),
                        "ACTIVE" => "Y",
                        "SITE_ID" => $arSitemap['SITE_ID'],
                        "!TOPICS" => 0,
                    ]
                );
                while ($res = $db_res->Fetch()) {
                    $arForums[$res['ID']] = $res;
                }
                $arForumList = array_intersect_key($arForums, $arForumList);

                foreach ($arForumList as $id => $forum) {
                    SitemapRuntimeTable::add([
                            'PID' => $PID,
                            'PROCESSED' => SitemapRuntimeTable::UNPROCESSED,
                            'ITEM_ID' => $id,
                            'ITEM_TYPE' => SitemapRuntimeTable::ITEM_TYPE_FORUM]
                    );

                    $fileName = str_replace('#FORUM_ID#', $forumId, $arSitemap['SETTINGS']['FILENAME_FORUM']);
                    $sitemapFile = new SitemapRuntimeCustom($PID, $fileName, $arSitemapSettings);
                }
            }

            $NS['FORUM_CURRENT_TOPIC'] = 0;

            if (count($arForumList) <= 0) {
                $v = $arValueSteps['forum'];
                $msg = Loc::getMessage('SITEMAP_RUN_FORUM_EMPTY');
            } else {
                $v = $arValueSteps['forum_index'];
                $msg = Loc::getMessage('SITEMAP_RUN_FORUM');
            }
        } elseif ($v < $arValueSteps['forum']) {
            $stepDuration = 10;
            $ts_finish = microtime(true) + $stepDuration * 0.95;

            $bFinished = false;
            $bCheckFinished = false;

            $currentForum = false;
            $forumId = 0;

            $dbTopicResult = null;
            $arTopic = null;

            while (!$bFinished && microtime(true) <= $ts_finish && CModule::IncludeModule("forum")) {
                if (!$currentForum) {
                    $arCurrentForum = false;
                    $dbRes = SitemapRuntimeTable::getList([
                        'order' => ['ID' => 'ASC'],
                        'filter' => [
                            'PID' => $PID,
                            'ITEM_TYPE' => SitemapRuntimeTable::ITEM_TYPE_FORUM,
                            'PROCESSED' => SitemapRuntimeTable::UNPROCESSED,
                        ],
                        'limit' => 1,
                    ]);

                    $currentForum = $dbRes->fetch();

                    if ($currentForum) {
                        $forumId = intval($currentForum['ITEM_ID']);

                        $db_res = CForumNew::GetListEx(
                            [],
                            [
                                'ID' => $forumId,
                                "ACTIVE" => "Y",
                                "SITE_ID" => $arSitemap['SITE_ID'],
                                "!TOPICS" => 0,
                            ]
                        );
                        $arCurrentForum = $db_res->Fetch();
                        if (!$arCurrentForum) {
                            SitemapRuntimeTable::update($currentForum['ID'], [
                                'PROCESSED' => SitemapRuntimeTable::PROCESSED,
                            ]);
                        } else {
                            $fileName = str_replace('#FORUM_ID#', $forumId, $arSitemap['SETTINGS']['FILENAME_FORUM']);
                            $sitemapFile = new SitemapRuntimeCustom($PID, $fileName, $arSitemapSettings);
                        }
                    }
                }

                if (!$currentForum) {
                    $bFinished = true;
                } elseif (is_array($arCurrentForum)) {
                    $bActive = (array_key_exists($forumId, $arSitemap['SETTINGS']['FORUM_TOPIC']) && $arSitemap['SETTINGS']['FORUM_TOPIC'][$forumId] == "Y");
                    if ($bActive) {
                        if ($dbTopicResult == null) {
                            $dbTopicResult = CForumTopic::GetList(
                                ["LAST_POST_DATE" => "DESC"],
                                array_merge(
                                    [
                                        "FORUM_ID" => $forumId,
                                        "APPROVED" => "Y"],
                                    ($NS['FORUM_CURRENT_TOPIC'] > 0 ? [
                                        ">ID" => $NS["FORUM_CURRENT_TOPIC"],
                                    ] : []
                                    )
                                ),
                                false,
                                0,
                                ['nTopCount' => 100]
                            );
                        }
                        if (($arTopic = $dbTopicResult->fetch()) && $arTopic) {
                            $NS["FORUM_CURRENT_TOPIC"] = $arTopic["ID"];
                            $url = CForumNew::PreparePath2Message(
                                $arCurrentForum["PATH2FORUM_MESSAGE"],
                                [
                                    "FORUM_ID" => $arCurrentForum["ID"],
                                    "TOPIC_ID" => $arTopic["ID"],
                                    "TITLE_SEO" => $arTopic["TITLE_SEO"],
                                    "MESSAGE_ID" => "s",
                                    "SOCNET_GROUP_ID" => $arTopic["SOCNET_GROUP_ID"],
                                    "OWNER_ID" => $arTopic["OWNER_ID"],
                                    "PARAM1" => $arTopic["PARAM1"],
                                    "PARAM2" => $arTopic["PARAM2"],
                                ]
                            );
                            $sitemapFile->addIBlockEntry($url, MakeTimeStamp($arTopic['LAST_POST_DATE']));
                        }
                    } else {
                        $url = CForumNew::PreparePath2Message(
                            $arCurrentForum["PATH2FORUM_MESSAGE"],
                            [
                                "FORUM_ID" => $arCurrentForum["ID"],
                                "TOPIC_ID" => $arCurrentForum["TID"],
                                "TITLE_SEO" => $arCurrentForum["TITLE_SEO"],
                                "MESSAGE_ID" => "s",
                                "SOCNET_GROUP_ID" => $arCurrentForum["SOCNET_GROUP_ID"],
                                "OWNER_ID" => $arCurrentForum["OWNER_ID"],
                                "PARAM1" => $arCurrentForum["PARAM1"],
                                "PARAM2" => $arCurrentForum["PARAM2"],
                            ]
                        );
                        $sitemapFile->addIBlockEntry($url, MakeTimeStamp($arCurrentForum['LAST_POST_DATE']));
                    }
                    if (empty($arTopic)) {
                        $bCheckFinished = false;
                        // we have finished current forum

                        SitemapRuntimeTable::update($currentForum['ID'], [
                            'PROCESSED' => SitemapRuntimeTable::PROCESSED,
                        ]);

                        if ($sitemapFile->isNotEmpty()) {
                            if ($sitemapFile->isCurrentPartNotEmpty()) {
                                $sitemapFile->finish();
                            } else {
                                $sitemapFile->delete();
                            }

                            if (!is_array($NS['XML_FILES']))
                                $NS['XML_FILES'] = [];

                            $NS['XML_FILES'] = array_merge($NS['XML_FILES'], $sitemapFile->getNameList());
                        } else {
                            $sitemapFile->delete();
                        }

                        $currentForum = false;
                        $dbTopicResult = null;
                        $NS['FORUM_CURRENT_TOPIC'] = 0;
                    }
                }
            }
            if ($v < $arValueSteps['forum'] - 1) {
                $msg = Loc::getMessage('SITEMAP_RUN_FORUM_NAME', ['#FORUM_NAME#' => $arCurrentForum['NAME']]);
                $v++;
            }

            if ($bFinished) {
                $v = $arValueSteps['forum'];
                $msg = Loc::getMessage('SITEMAP_RUN_FINALIZE');
            }
        } else {
            SitemapRuntimeTable::clearByPid($PID);

            $arFiles = [];

            $sitemapFile = new SitemapIndex($arSitemap['SETTINGS']['FILENAME_INDEX'], $arSitemapSettings);

            if (count($NS['XML_FILES']) > 0) {
                foreach ($NS['XML_FILES'] as $xmlFile) {
                    $arFiles[] = new IO\File(IO\Path::combine(
                        $sitemapFile->getSiteRoot(),
                        $xmlFile
                    ), $arSitemap['SITE_ID']);
                }
            }

            $sitemapFile->createIndex($arFiles);

            $arExistedSitemaps = [];

            if ($arSitemap['SETTINGS']['ROBOTS'] == 'Y') {
                $sitemapUrl = $sitemapFile->getUrl();

                $robotsFile = new RobotsFile($arSitemap['SITE_ID']);
                $robotsFile->addRule(
                    [RobotsFile::SITEMAP_RULE, $sitemapUrl]
                );

                $arSitemapLinks = $robotsFile->getRules(RobotsFile::SITEMAP_RULE);
                if (count($arSitemapLinks) > 1) // 1 - just added rule
                {
                    foreach ($arSitemapLinks as $rule) {
                        if ($rule[1] != $sitemapUrl) {
                            $arExistedSitemaps[] = $rule[1];
                        }
                    }
                }
            }

            $v = $arValueSteps['index'];
        }

        if ($v == $arValueSteps['index']) {
            $msg = Loc::getMessage('SITEMAP_RUN_FINISH');
            SitemapTable::update($ID, ['DATE_RUN' => new Bitrix\Main\Type\DateTime()]);
        }

        $NS = isset($_REQUEST['NS']) && is_array($_REQUEST['NS']) ? $_REQUEST['NS'] : (array)$NS;
    }

    ob_start();
    echo SitemapRuntimeCustom::showProgress($msg, Loc::getMessage('SEO_SITEMAP_RUN_TITLE'), $v);

    if (isset($arExistedSitemaps) && count($arExistedSitemaps) > 0) {
        echo Loc::getMessage('SEO_SITEMAP_RUN_ROBOTS_WARNING', [
            "#SITEMAPS#" => implode("\n", $arExistedSitemaps),
            "#LANGUAGE_ID#" => LANGUAGE_ID,
            "#SITE_ID#" => $arSitemap['SITE_ID'],
        ]);
    }

    $html = ob_get_contents();
    ob_end_clean();
}

/*
$arPrint = array(
	 'LAST_ELEMENT_ID' => $NS['LAST_ELEMENT_ID'],
	 'CURRENT_SECTION' => $NS['CURRENT_SECTION'],
	 'IBLOCK'          => $NS['IBLOCK'],
	 '$msg'            => $msg,
	 //'DOCUMENT_ROOT'      => $_SERVER['DOCUMENT_ROOT'],
	 //'$_REQUEST'          => $_REQUEST,
	 //'$html'              => $html,
);
$tttfile = dirname(__FILE__) . '/1_txt.php';
file_put_contents($tttfile, "<pre>" . print_r($arPrint, 1) . "</pre>\n", FILE_APPEND);
*/

//echo "<pre>";print_r($arPrint);echo "</pre>";