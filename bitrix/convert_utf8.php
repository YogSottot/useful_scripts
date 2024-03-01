<?
error_reporting(E_ALL & ~E_NOTICE);

if(version_compare(phpversion(), '5.0.0') == -1)
	die('PHP 5.0.0 or higher is required!');

require($_SERVER['DOCUMENT_ROOT'].'/bitrix/modules/main/include/prolog_before.php');
header("Content-type: text/html; charset=cp1251");
echo '<html><head><title>����������� ����� � UTF8</title></head><body>';

$STEP = intval($_REQUEST['step']);
if (!$STEP)
	$STEP = 1;
$strRes = '';
define('LIMIT', 10); // time limit

if (!$_REQUEST['go'])
{
	// ������������ ��������
	if (!function_exists('mb_convert_encoding'))
		Error('�� �������� ���������� mbstring');

	if (ini_get('mbstring.func_overload') != 2)
		Error('�������� ��������� mbstring.func_overload �� ����� 2');


	if (!defined('BX_UTF') || BX_UTF !== true)
		Error('��������� BX_UTF �� ���������� � true � /bitrix/php_interface/dbconn.php: <br><br><i>define("BX_UTF", true);</i>');

	$res = $DB->Query('SHOW VARIABLES LIKE "character_set_results"');
	$f = $res->Fetch();
	if (strtolower($f['Value']) != 'cp1251')
		Error('���� ������ �������� � ���������, �������� �� cp1251 (��������: '.$f['Value'].')');
}
else // GO!
{
	define('START_TIME', time()); // �������� ����� ������

	if ($STEP < 3)
	{
		define('START_PATH', $_SERVER['DOCUMENT_ROOT']); // ��������� ����� ��� ������
		if ($_REQUEST['break_point']) 
			define('SKIP_PATH',$_REQUEST['break_point']); // ������������� ����

		Search(START_PATH);
		if (defined('BREAK_POINT'))
		{
			?><form method=post id=postform>
				<input type=hidden name=step value="<?=$STEP?>">
				<input type=hidden name=go value=Y>
				<input type=hidden name=break_point value="<?=htmlspecialchars(BREAK_POINT)?>">
			</form>
			��� ���������...<br>
			������� ����: <i><?=htmlspecialchars(BREAK_POINT)?></i>
			<script>window.setTimeout("document.getElementById('postform').submit()",500);</script><? // ������� ����� ������� ������� �����
			die();
		}
		else
		{
			$strRes = "<font color=green><b>��� $STEP �������� �������</b></font>";
			$STEP++;
		}
	}
	elseif ($STEP == 3) // ����������� ����
	{
		if ($_REQUEST['break_point']) 
			define('SKIP_PATH',$_REQUEST['break_point']); // ������������� ����

		$res = $DB->Query('SHOW TABLES');
		while($f = $res->Fetch())
		{
			$table = $f['Tables_in_'.$DBName];
			if (defined('SKIP_PATH') && !defined('FOUND'))
			{
				if ($table == SKIP_PATH)
					define('FOUND', true);
				else
					continue;
			}

			$DB->Query('ALTER TABLE `'.$table.'` CHARACTER SET utf8 COLLATE utf8_unicode_ci');
			$res0 = $DB->Query('SHOW FULL COLUMNS FROM `'.$table.'`');
			while($f0 = $res0->Fetch())
			{
				if (false!==strpos($f0['Type'],'char') || false!==strpos($f0['Type'],'text'))
				{
					$Collation = strpos($f0['Collation'], '_bin') ? 'utf8_bin' : 'utf8_unicode_ci';
					$q = 'ALTER TABLE `'.$table.'` MODIFY `'.$f0['Field'].'` '.$f0['Type'].' CHARACTER SET utf8 COLLATE '.$Collation.($f0['Null']!='YES'?' NOT ':'').' NULL '.($f0['Default'] === NULL ? ($f0['Null'] == 'YES' ? 'DEFAULT NULL' : '') : 'DEFAULT "'.$DB->ForSql($f0['Default']).'"');
					$DB->Query($q);
					if (time() - START_TIME > LIMIT)
					{
						if (!defined('BREAK_POINT'))
							define('BREAK_POINT', $table);
						break;
					}
				}
			}

			if (defined('BREAK_POINT'))
				break;
		}

		if (defined('BREAK_POINT'))
		{
			?><form method=post id=postform>
				<input type=hidden name=step value="<?=$STEP?>">
				<input type=hidden name=go value=Y>
				<input type=hidden name=break_point value="<?=htmlspecialchars(BREAK_POINT)?>">
			</form>
			��� ���������...<br>
			������� �������: <i><?=htmlspecialchars(BREAK_POINT)?></i>
			<script>window.setTimeout("document.getElementById('postform').submit()",500);</script><? // ������� ����� ������� ������� �����
			die();
		}
		else
		{
			$DB->Query('ALTER DATABASE `'.$DBName.'` DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci');
			die("
			<font color=green><b>��� $STEP �������� �������. <br>����������� ���������.</b></font>
			<br>��������� ������:
			<li>���������� � <b>/bitrix/php_interface/after_connect.php</b>:<br>
				<i>\$DB-&gt;Query(&quot;SET NAMES 'utf8'&quot;);</i><br>
				<i>\$DB->Query('SET collation_connection = &quot;utf8_unicode_ci&quot;');</i>

			<li>�������� ��������� <a href='/bitrix/admin/lang_edit.php?LID=ru' target=_blank>�����</a> � <a href='/bitrix/admin/site_admin.php' target=_blank>������</a> �� utf-8, ���� ��� �� �������
			<li>������� ���� ��� � <a href='/bitrix/admin/cache.php'>���������������� ������</a>
			<div style='color:red'>����������� ������� ".__FILE__."!</div>");
		}
	}
}

$arStep = array(
	0,
	'�������� ���� �������',
	'����������� ������ � UTF8',
	'����������� ���� ������ � UTF8'
)

?>
<h1>����������� ����� � utf8</h1>
<p>������ �������, ���������� � �����: <a href="http://dev.1c-bitrix.ru/community/blogs/howto/1466.php">http://dev.1c-bitrix.ru/community/blogs/howto/1466.php</a></p>
<?=$strRes?>
<form method=post>
	<h2>��� <?=$STEP?></h2>
	<input type=hidden name=step value="<?=$STEP?>">
	<input type=submit name=go value="<?=$arStep[$STEP]?>">
	<?=($STEP == 1 ? '<input type=button onclick="document.location=\'?step=3\'" value="������� � ����������� ����">' : '' )?>
</form>
<?

function Search($path)
{
	if (time() - START_TIME > LIMIT)
	{
		if (!defined('BREAK_POINT'))
			define('BREAK_POINT', $path);
		return;
	}

	if (defined('SKIP_PATH') && !defined('FOUND')) // ��������, ������� �� ������� ����
	{
		if (0!==strpos(SKIP_PATH, dirname($path))) // ����������� ��� ��� ��� ���� 
			return;

		if (SKIP_PATH==$path) // ���� ������, ���������� ������ �����
			define('FOUND',true);
	}

	if (is_dir($path)) // dir
	{
		$dir = opendir($path);
		while($item = readdir($dir))
		{
			if ($item == '.' || $item == '..')
				continue;

			Search($path.'/'.$item);
		}
		closedir($dir);
	}
	else // file
	{
		if (!defined('SKIP_PATH') || defined('FOUND'))
		{
			if ((substr($path,-3) == '.js' || substr($path,-4) == '.php' || basename($path) == 'trigram') && $path != __FILE__)
				Process($path);
		}
	}
}

function Process($file)
{
	global $STEP;

	if ($STEP == 1)
	{
		if (!is_writable($file))
			Error('���� �� �������� �� ������: '.$file);
	}
	elseif ($STEP == 2)
	{
		$content = file_get_contents($file);

		if (GetStringCharset($content) != 'cp1251')
			return;

		if ($content === false)
			Error('�� ������� ��������� ����: '.$file);

		if (file_put_contents($file, mb_convert_encoding($content, 'utf8', 'cp1251')) === false)
			Error('�� ������� ��������� ����: '.$file);
		
	}
}

function GetStringCharset($str)
{ 
	global $APPLICATION;
	if (preg_match("/[\xe0\xe1\xe3-\xff]/",$str))
		return 'cp1251';
	$str0 = $APPLICATION->ConvertCharset($str, 'utf8', 'cp1251');
	if (preg_match("/[\xe0\xe1\xe3-\xff]/",$str0,$regs))
		return 'utf8';
	return 'ascii';
}

function Error($text)
{
	die('<font color=red>'.$text.'</font>');
}
?>
