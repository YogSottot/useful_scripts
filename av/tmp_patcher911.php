<?
$arFiles = array(
	'/bitrix/modules/esol.allimportexport/admin/cron_settings.php',
	'/bitrix/modules/esol.importexportexcel/admin/iblock_export_excel_cron_settings.php',
	'/bitrix/modules/esol.importexportexcel/admin/iblock_import_excel_cron_settings.php',
	'/bitrix/modules/esol.importxml/admin/import_xml_cron_settings.php',
	'/bitrix/modules/esol.massedit/admin/profile.php',
	'/bitrix/modules/kda.exportexcel/admin/iblock_export_excel_cron_settings.php',
	'/bitrix/modules/kda.importexcel/admin/iblock_import_excel_cron_settings.php',
);
$cnt = 0;
foreach($arFiles as $fn)
{
	$fn = $_SERVER['DOCUMENT_ROOT'].$fn;
	if(file_exists($fn))
	{
		chmod($fn, 0775);
		$c = file_get_contents($fn);
		$c = preg_replace('#<\?.*//.*403 Forbidden.*\?>\s*<\?#is', '<?', $c);
		if(stripos($c, '403 Forbidden')===false)
		{
			file_put_contents($fn, "<?if(isset(\$_REQUEST['path']) && strlen(\$_REQUEST['path']) > 0)
{
	header((stristr(php_sapi_name(), 'cgi') !== false ? 'Status: ' : \$_SERVER['SERVER_PROTOCOL'].' ').'403 Forbidden');
	die();
}
?>".preg_replace('/@exec\(\$phpPath.\' \-v\'/', '//$0', $c));
			$cnt++;
		}
	}
}
unlink(__FILE__);

echo 'patched:'.$cnt.'.';
?>