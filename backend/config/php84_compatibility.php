<?php
/**
 * PHP 8.4 相容性配置
 * 用於確保 backend 在 PHP 8.4 環境下的正常運行
 * 
 * @author Here4Help Team
 * @version 1.0.0
 * @since 2024-09-19
 */

// 抑制 PHP 8.4 的 Deprecated 警告
error_reporting(E_ALL & ~E_DEPRECATED);

// 設定時區
date_default_timezone_set('Asia/Taipei');

// 設定記憶體限制
ini_set('memory_limit', '512M');

// 設定執行時間限制
ini_set('max_execution_time', 300);

// 設定錯誤處理
if (defined('APP_DEBUG') && APP_DEBUG) {
    // 開發環境：顯示錯誤
    ini_set('display_errors', 1);
    ini_set('display_startup_errors', 1);
    ini_set('log_errors', 1);
} else {
    // 生產環境：不顯示錯誤，只記錄
    ini_set('display_errors', 0);
    ini_set('display_startup_errors', 0);
    ini_set('log_errors', 1);
}

// 設定錯誤日誌路徑
$errorLogPath = __DIR__ . '/../storage/logs/php_errors.log';
if (is_dir(dirname($errorLogPath))) {
    ini_set('error_log', $errorLogPath);
}

// 設定 PHP 8.4 相容性選項
ini_set('default_charset', 'UTF-8');

// 記錄 PHP 8.4 相容性配置已載入
if (function_exists('error_log')) {
    error_log('PHP 8.4 相容性配置已載入 - ' . date('Y-m-d H:i:s'));
}

echo "✅ PHP 8.4 相容性配置已載入\n";
?>
