// Autorization
<?php
define("NOT_CHECK_PERMISSIONS", true);
require($_SERVER["DOCUMENT_ROOT"] . "/bitrix/modules/main/include/prolog_before.php");
if ($_REQUEST["ID"] > 0)
{
    $user = new CUser;
    $res = $user->Authorize((int)$_REQUEST["ID"]);
   echo '<a href="/bitrix/admin/">welcome</a>';
}else
    echo 'No ID';
