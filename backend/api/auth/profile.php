<?php
require_once __DIR__ . '/bootstrap.php';
// 載入 PHP 8.4 相容性配置

// 已棄用，重定向到新的 profile API
header('Location: ../account/profile.php' . ($_SERVER['QUERY_STRING'] ? '?' . $_SERVER['QUERY_STRING'] : ''), true, 301);
exit;
?> 