```php
  'exception_handling' => 
  array (
    'value' => 
    array (
      'debug' => ENV('DEBUG',false),
      'handled_errors_types' => 4437,
      'exception_errors_types' => 4437,
      'ignore_silence' => false,
      'assertion_throws_exception' => true,
      'assertion_error_type' => 256,
      'log' => array(
                        'class_name' => \Bex\Monolog\ExceptionHandlerLog::class,
                        'settings' => array(
                            'logger' => 'app'
                        ),
                    ),
    ),
    'readonly' => false,
  ),
```
