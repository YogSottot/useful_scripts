<?php

return array(
	'monolog' => array(
		'value' => array(
			'handlers' => array(
				'default' => array(
					'class' => \Monolog\Handler\StreamHandler::class,
					'level' => 'DEBUG',
					'stream' => env('LOG_FILE_PATH_APP'),
				),
			),
			'loggers' => array(
				'app' => array(
					'handlers' => array('default'),
				),
			)
		),
		'readonly' => false
	)
);
