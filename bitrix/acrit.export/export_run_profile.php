<?php
/**
 * Запуск экспорта одного профиля acrit.exportpro.
 * Вызывается из bash-оркестратора export_feeds.sh.
 *
 * Использование:
 *   php export_run_profile.php profile_id=123
 *
 * Скрипт работает через агентный механизм (CExportproAgent::StartExport),
 * повторяя поведение cron_events.php, но для одного конкретного профиля.
 */

$_SERVER['DOCUMENT_ROOT'] = dirname(__FILE__, 4);
$DOCUMENT_ROOT = $_SERVER['DOCUMENT_ROOT'];

// Разбор аргументов CLI
if ($argv) {
    unset($argv[0]);
    parse_str(join('&', $argv), $_REQUEST);
}

$profileId = intval($_REQUEST['profile_id'] ?? 0);
if ($profileId <= 0) {
    fwrite(STDERR, "Error: profile_id is required\n");
    exit(1);
}

const NO_KEEP_STATISTIC = true;
const NOT_CHECK_PERMISSIONS = true;
const NO_AGENT_STATISTIC = true;
const STOP_STATISTICS = true;
const BX_CRONTAB_SUPPORT = true;
const BX_CRONTAB = true;
const BX_NO_ACCELERATOR_RESET = true;
const LANGUAGE_ID = 'ru';

error_reporting(E_ERROR | E_WARNING | E_PARSE);
ini_set('display_errors', 1);
ini_set('memory_limit', '512M');

@set_time_limit(0);
@ignore_user_abort(true);

require($_SERVER["DOCUMENT_ROOT"] . "/bitrix/modules/main/include/prolog_before.php");

if (!\Bitrix\Main\Loader::includeModule("acrit.exportpro")) {
    fwrite(STDERR, "Error: cannot load acrit.exportpro module\n");
    exit(1);
}

global $DB;

// Ищем агентов для этого профиля, у которых наступило время выполнения
$strSql = "
    SELECT ID, NAME, AGENT_INTERVAL, IS_PERIOD, MODULE_ID
    FROM b_agent
    WHERE ACTIVE = 'Y'
      AND NEXT_EXEC <= NOW()
      AND (DATE_CHECK IS NULL OR DATE_CHECK <= NOW())
      AND MODULE_ID = 'acrit.exportpro'
      AND NAME LIKE 'CExportproAgent::StartExport({$profileId},%'
    ORDER BY RUNNING ASC, SORT DESC
";

$dbAgents = $DB->Query($strSql);
$arAgents = [];
$ids = "";
while ($arAgent = $dbAgents->Fetch()) {
    $arAgents[] = $arAgent;
    $ids .= ($ids != "" ? ", " : "") . $arAgent["ID"];
}

if (empty($arAgents)) {
    // Нет готовых к запуску агентов для этого профиля — ничего не делаем
    exit(0);
}

// Блокируем агентов (увеличиваем DATE_CHECK чтобы cron_events.php не подхватил их параллельно)
if ($ids != "") {
    $DB->Query("UPDATE b_agent SET DATE_CHECK = DATE_ADD(IF(DATE_CHECK IS NULL, NOW(), DATE_CHECK), INTERVAL 3600 SECOND) WHERE ID IN ({$ids})");
}

$startTime = microtime(true);

foreach ($arAgents as $arAgent) {
    if (strlen($arAgent["MODULE_ID"]) > 0 && $arAgent["MODULE_ID"] != "main") {
        if (!CModule::IncludeModule($arAgent["MODULE_ID"])) {
            continue;
        }
    }

    // Ставим статус RUNNING
    $DB->Query("UPDATE b_agent SET RUNNING='Y' WHERE ID=" . $arAgent["ID"]);

    global $pPERIOD;
    $pPERIOD = $arAgent["AGENT_INTERVAL"];

    CTimeZone::Disable();

    global $USER;
    unset($USER);

    $evalResult = "";
    try {
        $e = eval("\$evalResult=" . $arAgent["NAME"]);
    } catch (\Exception $e) {
        CTimeZone::Enable();
        $DB->Query("UPDATE b_agent SET RUNNING='N', DATE_CHECK=NULL WHERE ID=" . $arAgent["ID"]);

        $application = \Bitrix\Main\Application::getInstance();
        $exceptionHandler = $application->getExceptionHandler();
        $exceptionHandler->writeToLog($e);
        continue;
    }

    unset($USER);
    CTimeZone::Enable();

    if ($e === false) {
        // Синтаксическая ошибка — сбрасываем RUNNING
        $DB->Query("UPDATE b_agent SET RUNNING='N', DATE_CHECK=NULL WHERE ID=" . $arAgent["ID"]);
        continue;
    } elseif (strlen($evalResult) <= 0) {
        $DB->Query("DELETE FROM b_agent WHERE ID=" . $arAgent["ID"]);
    } else {
        $strSql = "
            UPDATE b_agent SET
                NAME='" . $DB->ForSQL($evalResult, 2000) . "',
                LAST_EXEC=NOW(),
                NEXT_EXEC=DATE_ADD(" . ($arAgent["IS_PERIOD"] == "Y" ? "NEXT_EXEC" : "NOW()") . ", INTERVAL " . $pPERIOD . " SECOND),
                DATE_CHECK=NULL,
                RUNNING='N'
            WHERE ID=" . $arAgent["ID"];
        $DB->Query($strSql);
    }
}

$elapsed = round(microtime(true) - $startTime, 2);
echo "Profile {$profileId}: completed in {$elapsed}s\n";
