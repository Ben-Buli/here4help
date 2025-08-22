<?php
/**
 * 安全相關資料清理腳本
 * 清理過期的節流記錄和 JWT 黑名單
 * 
 * 建議每小時執行一次：
 * 0 * * * * /usr/bin/php /path/to/backend/cron/cleanup_security.php
 */

require_once __DIR__ . '/../utils/RateLimiter.php';
require_once __DIR__ . '/../utils/JWTManager.php';

// 設定時區
date_default_timezone_set('Asia/Taipei');

// 記錄開始時間
$startTime = microtime(true);
$logFile = __DIR__ . '/../storage/logs/cleanup_security.log';

// 確保日誌目錄存在
$logDir = dirname($logFile);
if (!is_dir($logDir)) {
    mkdir($logDir, 0755, true);
}

function logMessage($message) {
    global $logFile;
    $timestamp = date('Y-m-d H:i:s');
    file_put_contents($logFile, "[$timestamp] $message\n", FILE_APPEND | LOCK_EX);
    echo "[$timestamp] $message\n";
}

try {
    logMessage("開始安全資料清理作業");
    
    // 1. 清理過期的節流記錄
    logMessage("清理節流記錄...");
    $rateLimitCleaned = RateLimiter::cleanup();
    logMessage("清理了 $rateLimitCleaned 個過期的節流記錄");
    
    // 2. 清理過期的 JWT 黑名單記錄
    logMessage("清理 JWT 黑名單記錄...");
    $blacklistCleaned = JWTManager::cleanupBlacklist();
    logMessage("清理了 $blacklistCleaned 個過期的黑名單記錄");
    
    // 3. 清理舊的日誌檔案（保留 30 天）
    logMessage("清理舊日誌檔案...");
    $logsCleaned = cleanupOldLogs();
    logMessage("清理了 $logsCleaned 個舊日誌檔案");
    
    // 計算執行時間
    $endTime = microtime(true);
    $executionTime = round(($endTime - $startTime) * 1000, 2);
    
    logMessage("安全資料清理完成，執行時間: {$executionTime}ms");
    logMessage("總計清理: 節流記錄 $rateLimitCleaned 個，黑名單記錄 $blacklistCleaned 個，日誌檔案 $logsCleaned 個");
    
} catch (Exception $e) {
    logMessage("清理作業發生錯誤: " . $e->getMessage());
    exit(1);
}

/**
 * 清理舊的日誌檔案
 */
function cleanupOldLogs() {
    $logDir = __DIR__ . '/../storage/logs';
    if (!is_dir($logDir)) {
        return 0;
    }
    
    $cutoffTime = time() - (30 * 24 * 60 * 60); // 30 天前
    $cleaned = 0;
    
    $files = glob($logDir . '/*.log');
    foreach ($files as $file) {
        if (filemtime($file) < $cutoffTime) {
            // 檢查檔案大小，如果太大就壓縮後刪除
            $fileSize = filesize($file);
            if ($fileSize > 10 * 1024 * 1024) { // 10MB
                // 壓縮大檔案
                $gzFile = $file . '.gz';
                if (function_exists('gzopen')) {
                    $gz = gzopen($gzFile, 'w9');
                    gzwrite($gz, file_get_contents($file));
                    gzclose($gz);
                    
                    unlink($file);
                    logMessage("壓縮並刪除大日誌檔案: " . basename($file) . " (大小: " . formatBytes($fileSize) . ")");
                } else {
                    unlink($file);
                    logMessage("刪除大日誌檔案: " . basename($file) . " (大小: " . formatBytes($fileSize) . ")");
                }
            } else {
                unlink($file);
            }
            $cleaned++;
        }
    }
    
    return $cleaned;
}

/**
 * 格式化檔案大小
 */
function formatBytes($size, $precision = 2) {
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];
    
    for ($i = 0; $size > 1024 && $i < count($units) - 1; $i++) {
        $size /= 1024;
    }
    
    return round($size, $precision) . ' ' . $units[$i];
}

// 如果是直接執行（非 include），輸出結果
if (basename(__FILE__) === basename($_SERVER['SCRIPT_NAME'])) {
    echo "清理作業完成\n";
}
?>
