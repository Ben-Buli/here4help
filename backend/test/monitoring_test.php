<?php
/**
 * 監控系統測試腳本
 * 測試日誌記錄和警報功能
 */

require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../utils/Logger.php';
require_once __DIR__ . '/../utils/AlertManager.php';

// 禁用自動日誌記錄
define('LOGGING_MIDDLEWARE_DISABLED', true);

echo "🧪 Here4Help 監控系統測試\n";
echo "========================\n\n";

try {
    // 測試 1: 基本日誌記錄
    echo "1. 測試基本日誌記錄\n";
    echo "-----------------\n";
    
    Logger::log(Logger::LEVEL_INFO, 'Test info message', ['test' => true], Logger::TYPE_REQUEST);
    Logger::logError('Test error message', ['error_code' => 'TEST_ERROR']);
    Logger::logBusiness('test_event', 'user_123', ['action' => 'test']);
    
    echo "✅ 基本日誌記錄測試完成\n\n";
    
    // 測試 2: 模擬 HTTP 響應日誌
    echo "2. 測試 HTTP 響應日誌\n";
    echo "-------------------\n";
    
    // 模擬一些正常響應
    for ($i = 0; $i < 5; $i++) {
        Logger::logResponse(200, ['status' => 'success'], ['request_id' => "req_$i"]);
    }
    
    // 模擬一些 4xx 錯誤
    for ($i = 0; $i < 3; $i++) {
        Logger::logResponse(404, ['error' => 'not found'], ['request_id' => "req_4xx_$i"]);
    }
    
    // 模擬一些 5xx 錯誤
    for ($i = 0; $i < 2; $i++) {
        Logger::logResponse(500, ['error' => 'server error'], ['request_id' => "req_5xx_$i"]);
    }
    
    echo "✅ HTTP 響應日誌測試完成\n\n";
    
    // 測試 3: 警報系統
    echo "3. 測試警報系統\n";
    echo "-------------\n";
    
    // 測試信息警報
    $infoAlertId = AlertManager::sendAlert(
        AlertManager::TYPE_SECURITY,
        AlertManager::LEVEL_INFO,
        '測試信息警報',
        ['test' => true]
    );
    echo "✅ 信息警報已發送 - ID: $infoAlertId\n";
    
    // 測試警告警報
    $warningAlertId = AlertManager::sendAlert(
        AlertManager::TYPE_PERFORMANCE,
        AlertManager::LEVEL_WARNING,
        '測試警告警報',
        ['performance_issue' => 'slow_query']
    );
    echo "✅ 警告警報已發送 - ID: $warningAlertId\n";
    
    // 測試關鍵警報
    $criticalAlertId = AlertManager::sendAlert(
        AlertManager::TYPE_ERROR_RATE,
        AlertManager::LEVEL_CRITICAL,
        '測試關鍵警報',
        ['error_rate' => 15.5]
    );
    echo "✅ 關鍵警報已發送 - ID: $criticalAlertId\n";
    
    echo "\n";
    
    // 測試 4: 檢查活躍警報
    echo "4. 檢查活躍警報\n";
    echo "-------------\n";
    
    $activeAlerts = AlertManager::getActiveAlerts();
    echo "發現 " . count($activeAlerts) . " 個活躍警報:\n";
    
    foreach ($activeAlerts as $alert) {
        echo "- [{$alert['level']}] {$alert['message']} ({$alert['timestamp']})\n";
    }
    
    echo "\n";
    
    // 測試 5: 解決警報
    echo "5. 測試解決警報\n";
    echo "-------------\n";
    
    $resolved = AlertManager::resolveAlert($infoAlertId, 'test_script');
    if ($resolved) {
        echo "✅ 警報 $infoAlertId 已解決\n";
    } else {
        echo "❌ 無法解決警報 $infoAlertId\n";
    }
    
    echo "\n";
    
    // 測試 6: 日誌統計
    echo "6. 測試日誌統計\n";
    echo "-------------\n";
    
    $stats = Logger::getStats(null, 1); // 最近 1 小時
    echo "日誌統計:\n";
    echo "- 總條目數: {$stats['total_entries']}\n";
    echo "- 錯誤數: {$stats['error_count']}\n";
    echo "- 警告數: {$stats['warning_count']}\n";
    
    if (!empty($stats['by_level'])) {
        echo "- 按級別分類:\n";
        foreach ($stats['by_level'] as $level => $count) {
            echo "  - $level: $count\n";
        }
    }
    
    if (!empty($stats['by_type'])) {
        echo "- 按類型分類:\n";
        foreach ($stats['by_type'] as $type => $count) {
            echo "  - $type: $count\n";
        }
    }
    
    echo "\n";
    
    // 測試 7: 模擬連續 5xx 錯誤
    echo "7. 測試連續 5xx 錯誤檢測\n";
    echo "----------------------\n";
    
    // 模擬連續 6 個 5xx 錯誤
    for ($i = 0; $i < 6; $i++) {
        Logger::logResponse(500, ['error' => 'consecutive server error'], [
            'request_id' => "consecutive_5xx_$i",
            'timestamp' => date('Y-m-d H:i:s')
        ]);
        usleep(100000); // 0.1 秒間隔
    }
    
    // 檢查是否觸發警報
    $consecutiveAlertId = AlertManager::checkConsecutive5xxErrors(5);
    if ($consecutiveAlertId) {
        echo "🚨 連續 5xx 錯誤警報已觸發 - ID: $consecutiveAlertId\n";
    } else {
        echo "✅ 連續 5xx 錯誤檢測正常\n";
    }
    
    echo "\n";
    
    // 測試 8: 模擬高錯誤率
    echo "8. 測試高錯誤率檢測\n";
    echo "-----------------\n";
    
    // 模擬高錯誤率場景（10 個請求中有 3 個錯誤 = 30%）
    for ($i = 0; $i < 7; $i++) {
        Logger::logResponse(200, ['status' => 'success'], ['request_id' => "normal_$i"]);
    }
    for ($i = 0; $i < 3; $i++) {
        Logger::logResponse(500, ['error' => 'server error'], ['request_id' => "error_$i"]);
    }
    
    // 檢查錯誤率
    $errorRateAlertId = AlertManager::checkErrorRate(5.0); // 5% 閾值
    if ($errorRateAlertId) {
        echo "⚠️  高錯誤率警報已觸發 - ID: $errorRateAlertId\n";
    } else {
        echo "✅ 錯誤率檢測正常\n";
    }
    
    echo "\n";
    
    // 最終統計
    echo "9. 最終統計\n";
    echo "---------\n";
    
    $finalActiveAlerts = AlertManager::getActiveAlerts();
    echo "測試完成後活躍警報數: " . count($finalActiveAlerts) . "\n";
    
    $finalStats = Logger::getStats(null, 1);
    echo "測試完成後日誌條目數: {$finalStats['total_entries']}\n";
    echo "測試完成後錯誤數: {$finalStats['error_count']}\n";
    
    echo "\n🎉 監控系統測試完成！\n";
    
} catch (Exception $e) {
    echo "❌ 測試失敗: " . $e->getMessage() . "\n";
    echo "堆疊追蹤:\n" . $e->getTraceAsString() . "\n";
    exit(1);
}
