## Используем .env в битрикс для mysql

Помещаем файл `.preparations.php` в `bitrix/`.  
В файлах `bitrix/.settings.php` и `bitrix/php_interface/dbconn.php` подключаем в начале, после открывающего тега файл `.preparations.php`  
Пример  

```php
<?php
require $_SERVER['DOCUMENT_ROOT'] . '/bitrix/.preparations.php';

```

Пример использования для параметров mysql в .settings.php  

```php
  'connections' => 
  array (
    'value' => 
    array (
      'default' => 
      array (
        'className' => '\\Bitrix\\Main\\DB\\MysqliConnection',
        'host' => env('DB_HOST', 'localhost'),
        'database' => env('DB_NAME', 'dev'),
        'login' => env('DB_LOGIN', 'dev'),
        'password' => env('DB_PASSWORD', 'pass'),
        'options' => 2.0,
      ),
    ),
    'readonly' => true,
  ),

```

Пример для dbconn.php

```php
$DBHost = env('DB_HOST', 'mysql');
$DBLogin = env('DB_LOGIN', 'app');
$DBPassword = env('DB_PASSWORD', 'app');
$DBName = env('DB_NAME', 'app');
$DBDebug = env('DEBUG', false);
$DBDebugToFile = env('DEBUG_TO_FILE', false);

```

Путь к файлу `.env` можно отредактировать в файле `.preparations.php`
