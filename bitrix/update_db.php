<?php
if ($argc != 4) {
    die("Usage: php update_db_dev.php <target_site_path> <dev_domain> <domain_list_file>\n");
}

$targetDir    = rtrim($argv[1], '/');
$devDomain    = $argv[2];
$domainListFN = $argv[3];

define("NO_KEEP_STATISTIC", true);
define("NOT_CHECK_PERMISSIONS", true);
define("BX_CRONTAB_SUPPORT", true);
define("CLI_MODE", true);

// Set DOCUMENT_ROOT if not set
if (!isset($_SERVER["DOCUMENT_ROOT"]) || empty($_SERVER["DOCUMENT_ROOT"])) {
    $_SERVER["DOCUMENT_ROOT"] = $targetDir;
}

// Optionally, define a default HTTP_HOST for CLI mode if needed by Bitrix modules
if (!isset($_SERVER["HTTP_HOST"]) || empty($_SERVER["HTTP_HOST"])) {
    $_SERVER["HTTP_HOST"] = $devDomain;
}

$prologPath = $targetDir . "/bitrix/modules/main/include/prolog_before.php";
if (!file_exists($prologPath)) {
    die("Bitrix prolog file not found at: $prologPath\n");
}
require($prologPath);

/*
 *  --- Update settings using Bitrix API ---
 */

// Disable auto backup
COption::SetOptionString("main", "dump_auto_enable_auto", "0");

// Mark installation as development (should not be public)
COption::SetOptionString("main", "update_devsrv", "Y");

// Disable storing sessions in DB
COption::SetOptionString("security", "session", "N");

// Disable TOTP features
COption::SetOptionString("security", "otp_enabled", "N");
COption::SetOptionString("security", "otp_mandatory_using", "N");

// Remove all domain entries from b_lang_domain using direct DB query
global $DB;
$tableName = $DB->DBPrefix . "b_lang_domain";
$connection = \Bitrix\Main\Application::getConnection();
$connection->queryExecute("DELETE FROM {$tableName}");

// Clear DOC_ROOT for languages (if set)
$rsLang = CLang::GetList($by = "sort", $order = "asc");
while ($lang = $rsLang->Fetch()) {
    if (!empty($lang["DOC_ROOT"])) {
        CLang::Update($lang["LID"], array("DOC_ROOT" => null));
    }
}

// Update security policy for the default admin group (ID 1)
$arPolicy = array(
    "SECURITY_POLICY" => 'a:12:{s:15:"SESSION_TIMEOUT";s:4:"3600";s:15:"SESSION_IP_MASK";s:7:"0.0.0.0";s:13:"MAX_STORE_NUM";s:3:"100";s:13:"STORE_IP_MASK";s:7:"0.0.0.0";s:13:"STORE_TIMEOUT";s:4:"4320";s:17:"CHECKWORD_TIMEOUT";s:2:"60";s:15:"PASSWORD_LENGTH";s:2:"10";s:18:"PASSWORD_UPPERCASE";s:1:"Y";s:18:"PASSWORD_LOWERCASE";s:1:"Y";s:15:"PASSWORD_DIGITS";s:1:"Y";s:20:"PASSWORD_PUNCTUATION";s:1:"Y";s:14:"LOGIN_ATTEMPTS";s:1:"3";}'
);
$group = new CGroup();
if (!$group->Update(1, $arPolicy)) {
    echo "Failed to update group: " . $group->LAST_ERROR . "\n";
}

// Update the main module's server name (without protocol)
COption::SetOptionString("main", "server_name", $devDomain);

// Update the SERVER_NAME for site "s1" using CSite::Update instead of CLang::Update
$site = new CSite();
if (!$site->Update("s1", array("SERVER_NAME" => $devDomain))) {
    echo "Error updating site 's1': " . $site->LAST_ERROR . "\n";
}

/*
 *  --- Process domains from file ---
 *  Expected file format: each line starts with a site ID (LID) followed by space‑separated domain names.
 *  Example:
 *    s1 domain1.tld domain2.tld domain3.tld
 *    s2 domain4.tld domain5.tld
 */
if (file_exists($domainListFN)) {
    $lines = file($domainListFN, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        $parts = preg_split('/\s+/', trim($line));
        if (count($parts) < 2) {
            continue;
        }
        $lid = array_shift($parts);
        foreach ($parts as $domain) {
            $lidEsc = $DB->ForSQL($lid);
            $domainEsc = $DB->ForSQL($domain);
            $sql = "INSERT INTO {$tableName} (LID, DOMAIN) VALUES ('{$lidEsc}', '{$domainEsc}')";
            $connection->queryExecute($sql);
        }
    }
} else {
    echo "Domain list file not found: $domainListFN\n";
}

/*
 * --- Optional: Other settings via Bitrix API ---
 * // Disable pull/push server settings
 * COption::SetOptionString("pull", "nginx", "N");
 * COption::SetOptionString("pull", "push", "N");
 *
 * // Configure pull server (if needed)
 * COption::SetOptionString("pull", "server_mode", "personal");
 * COption::SetOptionString("pull", "signature_key", "BRfYy36Yjct");
 * COption::SetOptionString("pull", "path_to_publish", "http://dev.example.org:8895/bitrix/pub/");
 *
 * // Update email settings for admin/sale notifications
 * COption::SetOptionString("main", "all_bcc", "test@domain.tld");
 * COption::SetOptionString("main", "email_from", "test@domain.tld");
 * COption::SetOptionString("sale", "order_email", "test@domain.tld");
 * CLang::Update("s1", array("EMAIL" => "test@domain.tld"));
 * CLang::Update("s2", array("EMAIL" => "test@domain.tld"));
 *
 * // Optionally, temporarily close the public section
 * COption::SetOptionString("main", "site_stopped", "Y");
 */

// Finalize Bitrix environment
$epilogPath = $targetDir . "/bitrix/modules/main/include/epilog_after.php";
if (file_exists($epilogPath)) {
    echo "Database settings updated successfully.\n";  // Move message here
    require($epilogPath);
} else {
    echo "Database settings updated successfully.\n";
}
