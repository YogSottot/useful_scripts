<?php 
$_SERVER['DOCUMENT_ROOT'] = '/home/bitrix/www/';
require $_SERVER['DOCUMENT_ROOT'] . '/bitrix/modules/main/include.php';
//    CStatistics::CleanUpSessionData()
//    /bitrix/modules/statistic/classes/mysql/statistic.php:91

    //public static function CleanUpSessionData()
    //{
        __SetNoKeepStatistics();
        if ($_SESSION["SESS_NO_AGENT_STATISTIC"]!="Y" && !defined("NO_AGENT_STATISTIC"))
        {
            set_time_limit(0);
            ignore_user_abort(true);
            $err_mess = "File: ".__FILE__."<br>Line: ";
            $DB = CDatabase::GetModuleConnection('statistic');
            $php_session_time = intval(ini_get("session.gc_maxlifetime"));
            $strSql = "
                DELETE FROM b_stat_session_data WHERE
                    DATE_LAST < DATE_ADD(now(), INTERVAL - $php_session_time SECOND) or
                    DATE_LAST is null
                    ";
            $DB->Query($strSql, false, $err_mess.__LINE__);
        }
    //    return "CStatistics::CleanUpSessionData();";
    //}
