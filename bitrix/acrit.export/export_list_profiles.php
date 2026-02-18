<?php
/**
 * Выводит список ID активных профилей экспорта acrit.exportpro.
 * Используется bash-оркестратором export_feeds.sh для параллельного запуска.
 *
 * Вывод: по одному ID профиля на строку
 */

$_SERVER['DOCUMENT_ROOT'] = dirname(__FILE__, 4);

const NO_KEEP_STATISTIC = true;
const NOT_CHECK_PERMISSIONS = true;
const NO_AGENT_STATISTIC = true;
const STOP_STATISTICS = true;
const LANGUAGE_ID = 'ru';

error_reporting(E_ERROR);
ini_set('display_errors', 0);

@set_time_limit(30);

require($_SERVER["DOCUMENT_ROOT"] . "/bitrix/modules/main/include/prolog_before.php");

if (!\Bitrix\Main\Loader::includeModule("acrit.exportpro")) {
    exit(1);
}

global $DB;

// Получаем все активные профили, у которых тип запуска = cron
$strSql = "
    SELECT P.ID
    FROM acrit_exportpro_profile P
    WHERE P.ACTIVE = 'Y'
      AND P.TYPE_RUN = 'cron'
    ORDER BY P.ID ASC
";

$dbResult = $DB->Query($strSql);
while ($arProfile = $dbResult->Fetch()) {
    echo $arProfile['ID'] . "\n";
}
