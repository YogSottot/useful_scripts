<?php
if ($argc !== 3) {
    die("Usage: php devadmins.php <target_site_path> <admins_file>\n");
}

$targetDir = rtrim($argv[1], '/');
$adminsFile = $argv[2];

// Set necessary constants for CLI mode
define("NO_KEEP_STATISTIC", true);
define("NOT_CHECK_PERMISSIONS", true);
define("BX_CRONTAB_SUPPORT", true);
define("CLI_MODE", true);

// Set the document root to the target site path
if (!isset($_SERVER["DOCUMENT_ROOT"]) || empty($_SERVER["DOCUMENT_ROOT"])) {
    $_SERVER["DOCUMENT_ROOT"] = $targetDir;
}

// Include Bitrix core (prolog) from the target (dev) site.
$prologPath = $targetDir . "/bitrix/modules/main/include/prolog_before.php";
if (!file_exists($prologPath)) {
    die("Bitrix prolog file not found at: $prologPath\n");
}
require($prologPath);

// Check that the admins file exists.
if (!file_exists($adminsFile)) {
    die("Admins file not found: $adminsFile\n");
}

// Read the file line by line. Each line must contain: username password
$lines = file($adminsFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
foreach ($lines as $line) {
    $parts = preg_split('/\s+/', trim($line));
    if (count($parts) < 2) {
        echo "Invalid line format: $line\n";
        continue;
    }
    list($login, $password) = $parts;

    // Check if the user already exists.
    $res = CUser::GetByLogin($login);
    if ($user = $res->Fetch()) {
        echo "User $login already exists.\n";
        continue;
    }

    // Create the user with admin privileges (assuming group ID 1 is for admins).
    $user = new CUser;
    $arFields = array(
        "NAME"             => $login,
        "LOGIN"            => $login,
        "PASSWORD"         => $password,
        "CONFIRM_PASSWORD" => $password,
        "EMAIL"            => $login, // adjust as needed
        "ACTIVE"           => "Y",
        "GROUP_ID"         => array(1)
    );
    $ID = $user->Add($arFields);
    if (intval($ID) > 0) {
        echo "User $login added successfully. ID: $ID\n";
    } else {
        echo "Error adding user $login: " . $user->LAST_ERROR . "\n";
    }
}

// Clean up Bitrix environment.
$epilogPath = $targetDir . "/bitrix/modules/main/include/epilog_after.php";
if (file_exists($epilogPath)) {
    require($epilogPath);
}
