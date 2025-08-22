<?php
/**
 * 通知處理器 Cron 作業
 * 定期處理通知佇列中的待發送通知
 */

require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../utils/NotificationManager.php';
require_once __DIR__ . '/../utils/Logger.php';

// 防止重複執行
$lockFile = sys_get_temp_dir() . '/notification_processor.lock';

if (file_exists($lockFile)) {
    $lockTime = filemtime($lockFile);
    if (time() - $lockTime < 300) { // 5分鐘內不重複執行
        echo "通知處理器已在執行中，跳過此次執行\n";
        exit(0);
    }
    unlink($lockFile);
}

// 建立鎖檔案
touch($lockFile);

try {
    echo "🚀 開始處理通知佇列 - " . date('Y-m-d H:i:s') . "\n";
    
    $notificationManager = new NotificationManager();
    
    // 處理通知佇列
    $result = $notificationManager->processQueue();
    
    if ($result['success']) {
        echo "✅ 通知處理完成\n";
        echo "   處理數量: {$result['processed']}\n";
        echo "   成功數量: {$result['successful']}\n";
        echo "   失敗數量: " . ($result['processed'] - $result['successful']) . "\n";
        
        Logger::logBusiness('notification_cron_completed', null, [
            'processed' => $result['processed'],
            'successful' => $result['successful'],
            'failed' => $result['processed'] - $result['successful']
        ]);
    } else {
        echo "❌ 通知處理失敗: {$result['message']}\n";
        Logger::logError('notification_cron_failed', [], new Exception($result['message']));
    }
    
    // 清理過期的已處理通知（保留7天）
    echo "\n🧹 清理過期通知...\n";
    $cleanupResult = cleanupExpiredNotifications();
    
    if ($cleanupResult['success']) {
        echo "✅ 清理完成，刪除 {$cleanupResult['deleted']} 筆記錄\n";
    } else {
        echo "❌ 清理失敗: {$cleanupResult['message']}\n";
    }
    
    // 更新統計資料
    echo "\n📊 更新統計資料...\n";
    $statsResult = updateNotificationStats();
    
    if ($statsResult['success']) {
        echo "✅ 統計更新完成\n";
    } else {
        echo "❌ 統計更新失敗: {$statsResult['message']}\n";
    }
    
    echo "\n🎉 通知處理器執行完成 - " . date('Y-m-d H:i:s') . "\n";
    
} catch (Exception $e) {
    echo "❌ 通知處理器執行失敗: " . $e->getMessage() . "\n";
    Logger::logError('notification_cron_exception', [], $e);
} finally {
    // 清理鎖檔案
    if (file_exists($lockFile)) {
        unlink($lockFile);
    }
}

/**
 * 清理過期的通知記錄
 */
function cleanupExpiredNotifications() {
    try {
        $db = Database::getInstance()->getConnection();
        
        // 清理7天前已處理的通知佇列記錄
        $sql = "
            DELETE FROM notification_queue 
            WHERE status IN ('sent', 'failed') 
            AND updated_at < DATE_SUB(NOW(), INTERVAL 7 DAY)
        ";
        
        $stmt = $db->prepare($sql);
        $stmt->execute();
        $queueDeleted = $stmt->rowCount();
        
        // 清理30天前的站內通知（已讀且非置頂）
        $sql = "
            DELETE FROM in_app_notifications 
            WHERE is_read = 1 
            AND is_pinned = 0 
            AND read_at < DATE_SUB(NOW(), INTERVAL 30 DAY)
        ";
        
        $stmt = $db->prepare($sql);
        $stmt->execute();
        $inAppDeleted = $stmt->rowCount();
        
        // 清理過期的站內通知
        $sql = "
            DELETE FROM in_app_notifications 
            WHERE expires_at IS NOT NULL 
            AND expires_at < NOW()
        ";
        
        $stmt = $db->prepare($sql);
        $stmt->execute();
        $expiredDeleted = $stmt->rowCount();
        
        $totalDeleted = $queueDeleted + $inAppDeleted + $expiredDeleted;
        
        Logger::logBusiness('notification_cleanup_completed', null, [
            'queue_deleted' => $queueDeleted,
            'in_app_deleted' => $inAppDeleted,
            'expired_deleted' => $expiredDeleted,
            'total_deleted' => $totalDeleted
        ]);
        
        return [
            'success' => true,
            'deleted' => $totalDeleted,
            'details' => [
                'queue' => $queueDeleted,
                'in_app' => $inAppDeleted,
                'expired' => $expiredDeleted
            ]
        ];
        
    } catch (Exception $e) {
        Logger::logError('notification_cleanup_failed', [], $e);
        return [
            'success' => false,
            'message' => $e->getMessage()
        ];
    }
}

/**
 * 更新通知統計資料
 */
function updateNotificationStats() {
    try {
        $db = Database::getInstance()->getConnection();
        $today = date('Y-m-d');
        
        // 統計今日各模板和類型的發送情況
        $sql = "
            SELECT 
                template_key,
                notification_type,
                COUNT(*) as sent_count,
                SUM(CASE WHEN status = 'sent' THEN 1 ELSE 0 END) as delivered_count,
                SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed_count
            FROM notification_queue 
            WHERE DATE(created_at) = ?
            GROUP BY template_key, notification_type
        ";
        
        $stmt = $db->prepare($sql);
        $stmt->execute([$today]);
        $stats = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // 更新或插入統計資料
        $upsertSql = "
            INSERT INTO notification_stats 
            (date, template_key, notification_type, sent_count, delivered_count, failed_count)
            VALUES (?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
            sent_count = VALUES(sent_count),
            delivered_count = VALUES(delivered_count),
            failed_count = VALUES(failed_count),
            updated_at = CURRENT_TIMESTAMP
        ";
        
        $upsertStmt = $db->prepare($upsertSql);
        
        foreach ($stats as $stat) {
            $upsertStmt->execute([
                $today,
                $stat['template_key'],
                $stat['notification_type'],
                $stat['sent_count'],
                $stat['delivered_count'],
                $stat['failed_count']
            ]);
        }
        
        // 統計站內通知的開啟情況
        $inAppSql = "
            SELECT 
                template_key,
                COUNT(*) as sent_count,
                SUM(CASE WHEN is_read = 1 THEN 1 ELSE 0 END) as opened_count
            FROM in_app_notifications 
            WHERE DATE(created_at) = ?
            AND template_key IS NOT NULL
            GROUP BY template_key
        ";
        
        $stmt = $db->prepare($inAppSql);
        $stmt->execute([$today]);
        $inAppStats = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        foreach ($inAppStats as $stat) {
            $sql = "
                INSERT INTO notification_stats 
                (date, template_key, notification_type, sent_count, opened_count)
                VALUES (?, ?, 'in_app', ?, ?)
                ON DUPLICATE KEY UPDATE
                opened_count = VALUES(opened_count),
                updated_at = CURRENT_TIMESTAMP
            ";
            
            $stmt = $db->prepare($sql);
            $stmt->execute([
                $today,
                $stat['template_key'],
                $stat['sent_count'],
                $stat['opened_count']
            ]);
        }
        
        Logger::logBusiness('notification_stats_updated', null, [
            'date' => $today,
            'queue_stats' => count($stats),
            'in_app_stats' => count($inAppStats)
        ]);
        
        return [
            'success' => true,
            'updated_stats' => count($stats) + count($inAppStats)
        ];
        
    } catch (Exception $e) {
        Logger::logError('notification_stats_update_failed', [], $e);
        return [
            'success' => false,
            'message' => $e->getMessage()
        ];
    }
}
