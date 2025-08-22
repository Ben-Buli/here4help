<?php
/**
 * 通知系統測試腳本
 * 測試通知模板、事件矩陣和通知管理器功能
 */

require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../utils/NotificationManager.php';
require_once __DIR__ . '/../utils/Logger.php';

echo "🧪 通知系統功能測試\n";
echo "==================\n\n";

try {
    // 測試1: 初始化通知模板
    echo "1. 初始化通知模板\n";
    echo "----------------\n";
    testTemplateInitialization();
    
    echo "\n";
    
    // 測試2: NotificationManager 基本功能
    echo "2. 測試 NotificationManager\n";
    echo "---------------------------\n";
    testNotificationManager();
    
    echo "\n";
    
    // 測試3: 事件觸發測試
    echo "3. 測試事件觸發\n";
    echo "---------------\n";
    testEventTrigger();
    
    echo "\n";
    
    // 測試4: 通知佇列處理
    echo "4. 測試通知佇列處理\n";
    echo "------------------\n";
    testQueueProcessing();
    
    echo "\n✅ 所有測試完成！\n";
    
} catch (Exception $e) {
    echo "❌ 測試失敗: " . $e->getMessage() . "\n";
    Logger::logError('notification_system_test_failed', [], $e);
    exit(1);
}

/**
 * 測試模板初始化
 */
function testTemplateInitialization() {
    try {
        // 執行模板初始化腳本
        echo "執行模板初始化...\n";
        
        // 模擬執行初始化腳本
        $output = shell_exec('php ' . __DIR__ . '/../database/notification_templates_seed.php 2>&1');
        
        if ($output) {
            echo "初始化輸出:\n";
            echo $output . "\n";
        }
        
        // 檢查資料庫中的模板數量
        $db = Database::getInstance()->getConnection();
        
        $templateCount = $db->query("SELECT COUNT(*) FROM notification_templates WHERE is_active = 1")->fetchColumn();
        $eventCount = $db->query("SELECT COUNT(*) FROM notification_events WHERE is_active = 1")->fetchColumn();
        
        echo "✅ 模板初始化完成\n";
        echo "   啟用模板: $templateCount 個\n";
        echo "   啟用事件: $eventCount 個\n";
        
        if ($templateCount == 0 || $eventCount == 0) {
            echo "⚠️  警告: 模板或事件數量為 0，可能初始化失敗\n";
        }
        
    } catch (Exception $e) {
        echo "❌ 模板初始化失敗: " . $e->getMessage() . "\n";
        throw $e;
    }
}

/**
 * 測試 NotificationManager 基本功能
 */
function testNotificationManager() {
    try {
        $manager = new NotificationManager();
        echo "✅ NotificationManager 實例化成功\n";
        
        // 測試統計功能
        $stats = $manager->getNotificationStats();
        echo "✅ 統計功能正常，返回 " . count($stats) . " 筆統計資料\n";
        
        // 測試佇列處理（空佇列）
        $result = $manager->processQueue(5);
        
        if ($result['success']) {
            echo "✅ 佇列處理功能正常\n";
            echo "   處理數量: {$result['processed']}\n";
            echo "   成功數量: {$result['successful']}\n";
        } else {
            echo "❌ 佇列處理失敗: {$result['message']}\n";
        }
        
    } catch (Exception $e) {
        echo "❌ NotificationManager 測試失敗: " . $e->getMessage() . "\n";
        throw $e;
    }
}

/**
 * 測試事件觸發
 */
function testEventTrigger() {
    try {
        $manager = new NotificationManager();
        
        // 創建測試使用者（如果不存在）
        $testUserId = createTestUser();
        
        // 測試任務建立事件
        echo "測試任務建立事件...\n";
        
        $eventData = [
            'id' => 999,
            'task_title' => '測試任務',
            'poster_name' => '測試發布者',
            'reward' => 100
        ];
        
        $result = $manager->triggerEvent('task', 'created', $eventData, [$testUserId]);
        
        if ($result['success']) {
            echo "✅ 任務建立事件觸發成功\n";
            echo "   佇列通知數: {$result['queued']}\n";
        } else {
            echo "❌ 任務建立事件觸發失敗: {$result['message']}\n";
        }
        
        // 測試聊天訊息事件
        echo "\n測試聊天訊息事件...\n";
        
        $chatEventData = [
            'id' => 888,
            'sender_name' => '測試發送者',
            'message_preview' => '這是一條測試訊息',
            'sender_id' => $testUserId
        ];
        
        $result = $manager->triggerEvent('chat', 'new_message', $chatEventData, [$testUserId]);
        
        if ($result['success']) {
            echo "✅ 聊天訊息事件觸發成功\n";
            echo "   佇列通知數: {$result['queued']}\n";
        } else {
            echo "❌ 聊天訊息事件觸發失敗: {$result['message']}\n";
        }
        
        // 測試不存在的事件
        echo "\n測試不存在的事件...\n";
        
        $result = $manager->triggerEvent('unknown', 'test', [], [$testUserId]);
        
        if ($result['success'] && $result['queued'] == 0) {
            echo "✅ 不存在事件處理正確（無通知產生）\n";
        } else {
            echo "⚠️  不存在事件處理異常\n";
        }
        
    } catch (Exception $e) {
        echo "❌ 事件觸發測試失敗: " . $e->getMessage() . "\n";
        throw $e;
    }
}

/**
 * 測試佇列處理
 */
function testQueueProcessing() {
    try {
        $manager = new NotificationManager();
        
        // 檢查佇列中的通知數量
        $db = Database::getInstance()->getConnection();
        $queueCount = $db->query("SELECT COUNT(*) FROM notification_queue WHERE status = 'pending'")->fetchColumn();
        
        echo "佇列中待處理通知: $queueCount 個\n";
        
        if ($queueCount > 0) {
            // 處理佇列
            $result = $manager->processQueue(10);
            
            if ($result['success']) {
                echo "✅ 佇列處理成功\n";
                echo "   處理數量: {$result['processed']}\n";
                echo "   成功數量: {$result['successful']}\n";
                
                // 檢查站內通知是否建立
                $inAppCount = $db->query("SELECT COUNT(*) FROM in_app_notifications")->fetchColumn();
                echo "   站內通知數: $inAppCount 個\n";
                
            } else {
                echo "❌ 佇列處理失敗: {$result['message']}\n";
            }
        } else {
            echo "ℹ️  佇列為空，跳過處理測試\n";
        }
        
        // 測試統計更新
        echo "\n測試統計更新...\n";
        updateTestStats();
        
    } catch (Exception $e) {
        echo "❌ 佇列處理測試失敗: " . $e->getMessage() . "\n";
        throw $e;
    }
}

/**
 * 創建測試使用者
 */
function createTestUser() {
    try {
        $db = Database::getInstance()->getConnection();
        
        // 檢查是否已存在測試使用者
        $sql = "SELECT id FROM users WHERE email = 'test_notification@example.com' LIMIT 1";
        $stmt = $db->prepare($sql);
        $stmt->execute();
        $existingUser = $stmt->fetch();
        
        if ($existingUser) {
            return $existingUser['id'];
        }
        
        // 創建測試使用者
        $sql = "
            INSERT INTO users (name, email, password, role, status, created_at) 
            VALUES ('測試通知使用者', 'test_notification@example.com', 'test_password', 'user', 'active', NOW())
        ";
        
        $stmt = $db->prepare($sql);
        $stmt->execute();
        
        $userId = $db->lastInsertId();
        echo "✅ 創建測試使用者 ID: $userId\n";
        
        return $userId;
        
    } catch (Exception $e) {
        echo "⚠️  使用現有使用者進行測試\n";
        // 返回一個可能存在的使用者 ID
        return 1;
    }
}

/**
 * 更新測試統計
 */
function updateTestStats() {
    try {
        $db = Database::getInstance()->getConnection();
        $today = date('Y-m-d');
        
        // 插入測試統計資料
        $sql = "
            INSERT INTO notification_stats 
            (date, template_key, notification_type, sent_count, delivered_count, opened_count)
            VALUES (?, 'task_created', 'push', 5, 4, 2)
            ON DUPLICATE KEY UPDATE
            sent_count = sent_count + VALUES(sent_count),
            delivered_count = delivered_count + VALUES(delivered_count),
            opened_count = opened_count + VALUES(opened_count)
        ";
        
        $stmt = $db->prepare($sql);
        $stmt->execute([$today]);
        
        echo "✅ 測試統計資料更新成功\n";
        
    } catch (Exception $e) {
        echo "⚠️  統計更新失敗: " . $e->getMessage() . "\n";
    }
}
