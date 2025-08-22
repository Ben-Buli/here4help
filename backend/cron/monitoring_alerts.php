<?php
/**
 * 監控警報 Cron 腳本
 * 定期檢查錯誤率和系統健康狀況
 */

require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../utils/Logger.php';
require_once __DIR__ . '/../utils/AlertManager.php';
require_once __DIR__ . '/../middleware/logging_middleware.php';

// 禁用自動日誌記錄（避免在 CLI 環境中出錯）
define('LOGGING_MIDDLEWARE_DISABLED', true);

echo "🔍 Here4Help 監控警報檢查\n";
echo "========================\n\n";

try {
    // 檢查最近 1 小時的錯誤統計
    echo "1. 檢查錯誤率\n";
    echo "-------------\n";
    
    $errorStats = Logger::getStats(Logger::TYPE_ERROR, 1);
    $responseStats = Logger::getStats(Logger::TYPE_RESPONSE, 1);
    
    echo "錯誤統計（最近 1 小時）:\n";
    echo "- 總錯誤數: {$errorStats['error_count']}\n";
    echo "- 總請求數: {$responseStats['total_entries']}\n";
    
    if ($responseStats['total_entries'] > 0) {
        $errorRate = ($errorStats['error_count'] / $responseStats['total_entries']) * 100;
        echo "- 錯誤率: " . number_format($errorRate, 2) . "%\n";
        
        // 錯誤率警報閾值
        $errorRateThreshold = 5.0; // 5%
        
        $alertId = AlertManager::checkErrorRate($errorRateThreshold);
        if ($alertId) {
            echo "⚠️  警報: 錯誤率過高 ({$errorRate}% > {$errorRateThreshold}%) - Alert ID: $alertId\n";
        } else {
            echo "✅ 錯誤率正常\n";
        }
    } else {
        echo "- 無請求數據\n";
    }
    
    echo "\n";
    
    // 檢查 5xx 錯誤連續發生
    echo "2. 檢查 5xx 錯誤\n";
    echo "---------------\n";
    
    $alertId = AlertManager::checkConsecutive5xxErrors(5);
    
    if ($alertId) {
        echo "🚨 嚴重警報: 連續 5xx 錯誤 - Alert ID: $alertId\n";
    } else {
        // 檢查較低閾值的警告
        $warningAlertId = AlertManager::checkConsecutive5xxErrors(3);
        if ($warningAlertId) {
            echo "⚠️  警告: 連續 5xx 錯誤 - Alert ID: $warningAlertId\n";
        } else {
            echo "✅ 5xx 錯誤狀況正常\n";
        }
    }
    
    echo "\n";
    
    // 檢查性能問題
    echo "3. 檢查性能指標\n";
    echo "-------------\n";
    
    $performanceStats = Logger::getStats(Logger::TYPE_PERFORMANCE, 1);
    
    if ($performanceStats['total_entries'] > 0) {
        echo "性能統計（最近 1 小時）:\n";
        echo "- 總操作數: {$performanceStats['total_entries']}\n";
        echo "- 警告數: {$performanceStats['warning_count']}\n";
        
        $slowOperationRate = ($performanceStats['warning_count'] / $performanceStats['total_entries']) * 100;
        echo "- 慢操作率: " . number_format($slowOperationRate, 2) . "%\n";
        
        if ($slowOperationRate > 10) {
            echo "⚠️  警告: 慢操作率過高 ({$slowOperationRate}%)\n";
            
            Logger::log(Logger::LEVEL_WARNING, 'High Slow Operation Rate', [
                'slow_operation_rate' => $slowOperationRate,
                'warning_count' => $performanceStats['warning_count'],
                'total_operations' => $performanceStats['total_entries']
            ], Logger::TYPE_PERFORMANCE);
        } else {
            echo "✅ 性能指標正常\n";
        }
    } else {
        echo "- 無性能數據\n";
    }
    
    echo "\n";
    
    // 檢查活躍警報
    echo "4. 檢查活躍警報\n";
    echo "-------------\n";
    
    $activeAlerts = AlertManager::getActiveAlerts();
    if (!empty($activeAlerts)) {
        echo "發現 " . count($activeAlerts) . " 個活躍警報:\n";
        foreach (array_slice($activeAlerts, 0, 5) as $alert) {
            echo "- [{$alert['level']}] {$alert['message']} ({$alert['timestamp']})\n";
        }
    } else {
        echo "✅ 無活躍警報\n";
    }
    
    echo "\n";
    
    // 清理舊日誌和警報
    echo "5. 清理舊檔案\n";
    echo "-----------\n";
    
    $cleanedLogs = Logger::cleanup(30); // 保留 30 天
    $cleanedAlerts = AlertManager::cleanup(30); // 保留 30 天
    echo "清理了 {$cleanedLogs} 個舊日誌檔案\n";
    echo "清理了 {$cleanedAlerts} 個舊警報檔案\n";
    
    echo "\n✅ 監控檢查完成\n";
    
} catch (Exception $e) {
    echo "❌ 監控檢查失敗: " . $e->getMessage() . "\n";
    
    Logger::logError('Monitoring check failed', [], $e);
    exit(1);
}


