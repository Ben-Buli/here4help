<?php
/**
 * 儲存清理 Cron 腳本
 * 定期清理過期檔案、臨時檔案和孤兒檔案
 */

require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../utils/StorageManager.php';
require_once __DIR__ . '/../utils/Logger.php';

// 禁用自動日誌記錄
define('LOGGING_MIDDLEWARE_DISABLED', true);

echo "🧹 Here4Help 儲存清理系統\n";
echo "========================\n\n";

try {
    $storageManager = new StorageManager();
    
    // 獲取當前時間
    $currentHour = (int)date('H');
    $currentDay = (int)date('w'); // 0 = 星期日
    
    echo "當前時間: " . date('Y-m-d H:i:s') . "\n";
    echo "執行清理任務...\n\n";
    
    $startTime = microtime(true);
    
    // 執行清理
    $result = $storageManager->cleanupExpiredFiles();
    
    $duration = round(microtime(true) - $startTime, 2);
    
    if ($result['success']) {
        echo "✅ 清理完成！\n";
        echo "耗時: {$duration} 秒\n\n";
        
        $stats = $result['result'];
        echo "📊 清理統計:\n";
        echo "- 刪除檔案: {$stats['deleted_files']} 個\n";
        echo "- 釋放空間: " . formatBytes($stats['freed_space']) . "\n";
        echo "- 清理臨時檔案: {$stats['temp_deleted']} 個\n";
        
        if (!empty($stats['errors'])) {
            echo "- 錯誤數: " . count($stats['errors']) . "\n";
        }
        
    } else {
        echo "❌ 清理失敗: " . $result['error'] . "\n";
        exit(1);
    }
    
    // 每日凌晨2點執行深度清理
    if ($currentHour === 2) {
        echo "\n🔍 執行深度清理...\n";
        performDeepCleanup($storageManager);
    }
    
    // 每週日執行儲存統計報告
    if ($currentDay === 0 && $currentHour === 3) {
        echo "\n📈 生成週度儲存報告...\n";
        generateStorageReport($storageManager);
    }
    
    echo "\n🎉 所有清理任務完成\n";
    
} catch (Exception $e) {
    echo "❌ 清理失敗: " . $e->getMessage() . "\n";
    Logger::logError('Storage cleanup cron failed', [], $e);
    exit(1);
}

/**
 * 執行深度清理
 */
function performDeepCleanup($storageManager) {
    try {
        // 清理配額表中的無效記錄
        cleanupInvalidQuotas();
        
        // 重新計算配額使用量
        recalculateQuotas();
        
        // 清理訪問日誌 (保留90天)
        cleanupAccessLogs(90);
        
        echo "✅ 深度清理完成\n";
        
    } catch (Exception $e) {
        echo "❌ 深度清理失敗: " . $e->getMessage() . "\n";
        Logger::logError('Deep cleanup failed', [], $e);
    }
}

/**
 * 清理無效配額記錄
 */
function cleanupInvalidQuotas() {
    try {
        $db = Database::getInstance()->getConnection();
        
        // 刪除不存在用戶的配額記錄
        $sql = "
            DELETE mq FROM media_quotas mq
            LEFT JOIN users u ON mq.user_id = u.id
            WHERE u.id IS NULL
        ";
        
        $stmt = $db->prepare($sql);
        $stmt->execute();
        
        $deletedCount = $stmt->rowCount();
        echo "- 清理無效配額記錄: {$deletedCount} 筆\n";
        
    } catch (Exception $e) {
        Logger::logError('Failed to cleanup invalid quotas', [], $e);
    }
}

/**
 * 重新計算配額使用量
 */
function recalculateQuotas() {
    try {
        $db = Database::getInstance()->getConnection();
        
        // 重新計算每個用戶的配額使用量
        $sql = "
            UPDATE media_quotas mq
            SET 
                used_space = (
                    SELECT COALESCE(SUM(file_size), 0)
                    FROM media_files mf
                    WHERE mf.user_id = mq.user_id 
                    AND mf.context = mq.context 
                    AND mf.deleted_at IS NULL
                ),
                file_count = (
                    SELECT COUNT(*)
                    FROM media_files mf
                    WHERE mf.user_id = mq.user_id 
                    AND mf.context = mq.context 
                    AND mf.deleted_at IS NULL
                ),
                updated_at = NOW()
        ";
        
        $stmt = $db->prepare($sql);
        $stmt->execute();
        
        $updatedCount = $stmt->rowCount();
        echo "- 重新計算配額: {$updatedCount} 筆記錄\n";
        
    } catch (Exception $e) {
        Logger::logError('Failed to recalculate quotas', [], $e);
    }
}

/**
 * 清理訪問日誌
 */
function cleanupAccessLogs($days) {
    try {
        $db = Database::getInstance()->getConnection();
        
        $sql = "
            DELETE FROM media_access_logs 
            WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)
        ";
        
        $stmt = $db->prepare($sql);
        $stmt->execute([$days]);
        
        $deletedCount = $stmt->rowCount();
        echo "- 清理訪問日誌: {$deletedCount} 筆記錄\n";
        
    } catch (Exception $e) {
        Logger::logError('Failed to cleanup access logs', [], $e);
    }
}

/**
 * 生成儲存報告
 */
function generateStorageReport($storageManager) {
    try {
        $stats = $storageManager->getStorageStats();
        
        if (!$stats) {
            echo "❌ 無法獲取儲存統計\n";
            return;
        }
        
        $reportDir = __DIR__ . '/../database/reports';
        if (!is_dir($reportDir)) {
            mkdir($reportDir, 0755, true);
        }
        
        $reportFile = $reportDir . '/storage_report_' . date('Y-m-d') . '.md';
        
        $content = generateReportContent($stats);
        file_put_contents($reportFile, $content);
        
        echo "✅ 儲存報告已生成: " . basename($reportFile) . "\n";
        
        // 記錄報告生成
        Logger::logBusiness('storage_report_generated', null, [
            'report_file' => $reportFile,
            'total_files' => $stats['total_files'],
            'total_size' => $stats['total_size']
        ]);
        
    } catch (Exception $e) {
        echo "❌ 報告生成失敗: " . $e->getMessage() . "\n";
        Logger::logError('Storage report generation failed', [], $e);
    }
}

/**
 * 生成報告內容
 */
function generateReportContent($stats) {
    $content = "# 儲存系統週度報告\n\n";
    $content .= "**報告日期**: " . date('Y-m-d H:i:s') . "\n";
    $content .= "**儲存類型**: {$stats['storage_type']}\n\n";
    
    $content .= "## 📊 總體統計\n\n";
    $content .= "- **總檔案數**: " . number_format($stats['total_files']) . "\n";
    $content .= "- **總儲存空間**: " . formatBytes($stats['total_size']) . "\n";
    $content .= "- **平均檔案大小**: " . formatBytes($stats['total_size'] / max($stats['total_files'], 1)) . "\n\n";
    
    if (!empty($stats['by_context'])) {
        $content .= "## 📁 按情境分類\n\n";
        $content .= "| 情境 | 檔案數 | 總大小 | 平均大小 |\n";
        $content .= "|------|--------|--------|----------|\n";
        
        foreach ($stats['by_context'] as $context => $contextStats) {
            $content .= "| {$context} | " . number_format($contextStats['file_count']) . " | " . 
                       formatBytes($contextStats['total_size']) . " | " . 
                       formatBytes($contextStats['avg_size']) . " |\n";
        }
        
        $content .= "\n";
    }
    
    $content .= "## 📈 趨勢分析\n\n";
    $content .= "- 本週新增檔案數: (需要歷史數據比較)\n";
    $content .= "- 儲存空間增長: (需要歷史數據比較)\n";
    $content .= "- 熱門檔案類型: (需要詳細分析)\n\n";
    
    $content .= "## 🔧 建議\n\n";
    $content .= "1. **空間優化**: 定期清理過期檔案\n";
    $content .= "2. **壓縮策略**: 對大圖片啟用壓縮\n";
    $content .= "3. **CDN 配置**: 考慮使用 CDN 加速檔案訪問\n";
    $content .= "4. **備份策略**: 確保重要檔案有備份\n\n";
    
    return $content;
}

/**
 * 格式化檔案大小
 */
function formatBytes($bytes, $precision = 2) {
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];
    
    for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
        $bytes /= 1024;
    }
    
    return round($bytes, $precision) . ' ' . $units[$i];
}
