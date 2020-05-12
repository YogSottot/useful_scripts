<?php
/*
* https://pai-bx.com/wiki/1c-bitrix/86-if-you-do-not-remember-the-password-from-the-backup/
 * Где-нибудь на сайте создаем файл вот с таким содержанием: 
 * 
 * И после этого, из консоли сервера запускаем данный файлик:
 * /usr/bin/php -f /home/bitrix/www/bitrix/php_interface/get_password_for_backup.php
 * если не помните лицензионный ключ, а хотите поднимать бекап из облака Битрикса - посмотреть ключ можно в папке ядра, в специальном файле:  /bitrix/license_key.php 
 * wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/get_password_for_backup.php
 * Если админка живая, то можно в административном разделе в функионал Командной строки прописываем:
* 
* require($_SERVER["DOCUMENT_ROOT"]."/bitrix/modules/main/classes/general/backup.php");
* var_dump(CPasswordStorage::Get('dump_temporary_cache'));
 */
<?$_SERVER["DOCUMENT_ROOT"] = realpath(dirname(__FILE__)."/../..");

$DOCUMENT_ROOT = $_SERVER["DOCUMENT_ROOT"];
define("NO_KEEP_STATISTIC", true);
define("NOT_CHECK_PERMISSIONS",true);
define('BX_NO_ACCELERATOR_RESET', true);

require($_SERVER["DOCUMENT_ROOT"]."/bitrix/modules/main/include/prolog_before.php");
require($_SERVER["DOCUMENT_ROOT"]."/bitrix/modules/main/classes/general/backup.php");

var_dump(CPasswordStorage::Get('dump_temporary_cache'));
