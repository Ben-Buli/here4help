<?php
/**
 * PHP 8.4 相容性配置
 * 抑制 Deprecated 警告
 */

// 抑制 PHP 8.4 的 Deprecated 警告
error_reporting(E_ALL & ~E_DEPRECATED);

// 設定時區
date_default_timezone_set('Asia/Taipei');

// 設定記憶體限制
ini_set('memory_limit', '512M');

// 設定執行時間限制
ini_set('max_execution_time', 300);

// 設定錯誤顯示
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);

echo "PHP 8.4 相容性配置已載入\n";
?>
