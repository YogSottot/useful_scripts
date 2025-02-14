<?php

use Bitrix\Main\SystemException;

/**
 * Проверяем был ли уже обработан автолоад
 *
 * Если нет - загружаем
 */
if (!class_exists(Dotenv\Dotenv::class)) {
	$vendorFile = $_SERVER['DOCUMENT_ROOT'] . '/bitrix/vendor/autoload.php';
	if (file_exists($vendorFile)) {
		/** @noinspection PhpIncludeInspection */
		require $vendorFile;
	}
}

/**
 * Было ли уже загружено .env окружение
 */
if (!function_exists('env')) {
	$dotenv = Dotenv\Dotenv::create($_SERVER['DOCUMENT_ROOT'] . '/../../site/config');
	if (!$dotenv->load()) {
		/** @noinspection PhpUnhandledExceptionInspection */
		throw new SystemException('Невозможно получить локальные настройки сайта');
	}
	
	/**
	 * Gets the value of an environment variable.
	 *
	 * @param string $key
	 * @param mixed $default
	 * @return mixed
	 */
	function env($key, $default = null)
	{
		$value = getenv($key);
		
		if ($value === false) {
			return $default;
		}
		
		switch (strtolower($value)) {
			case 'true':
			case '(true)':
				return true;
			case 'false':
			case '(false)':
				return false;
			case 'empty':
			case '(empty)':
				return '';
			case 'null':
			case '(null)':
				return null;
		}
		
		if (($valueLength = strlen($value)) > 1 && strpos($value, '"') === 0 && $value[$valueLength - 1] === '"') {
			return substr($value, 1, -1);
		}
		
		return $value;
	}
}
