<?php
// Include Composer autoload and Yii framework
require __DIR__ . '/vendor/autoload.php';
require(__DIR__ . '/vendor/yiisoft/yii2/Yii.php');

// Load the application configuration
$config = require(__DIR__ . '/config/web.php');

// Create an application instance without running it
$app = new yii\web\Application($config);

// Generate the password hash using Yii's security component
$newPassword = 'your_new_password'; // Replace with your desired password
$hash = Yii::$app->security->generatePasswordHash($newPassword);

echo "New hashed password: " . $hash . PHP_EOL;


// USE your_database_name;
// SELECT * FROM user WHERE username = 'admin';
// Update the admin password with the newly hashed password:
// Replace the password_hash field (or equivalent) with the hash generated earlier:
// UPDATE user SET password_hash = 'your_new_hash' WHERE username = 'admin';
