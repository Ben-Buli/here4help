<?php
/**
 * 檢查任務接受應徵的相關資料
 * 用於調試 users.id = 2 批准 users.id = 1 成為任務執行者的問題
 */

require_once __DIR__ . '/../config/database.php';

try {
    $db = Database::getInstance();
    
    $taskId = 'test-posted-2005-pending';
    $creatorId = 2;
    $participantId = 1;
    
    echo "=== 檢查任務接受應徵相關資料 ===\n";
    echo "任務 ID: $taskId\n";
    echo "創建者 ID: $creatorId\n";
    echo "應徵者 ID: $participantId\n\n";
    
    // 1. 檢查任務是否存在
    echo "1. 檢查任務是否存在:\n";
    $task = $db->fetch(
        "SELECT t.*, s.code AS status_code, s.display_name AS status_display 
         FROM tasks t 
         LEFT JOIN task_statuses s ON t.status_id = s.id 
         WHERE t.id = ?",
        [$taskId]
    );
    
    if (!$task) {
        echo "❌ 任務 '$taskId' 不存在\n";
        
        // 列出所有任務
        echo "\n📋 現有的任務列表:\n";
        $allTasks = $db->fetchAll("SELECT id, title, creator_id, status_id FROM tasks ORDER BY created_at DESC LIMIT 10");
        foreach ($allTasks as $t) {
            echo "  - ID: {$t['id']}, Title: {$t['title']}, Creator: {$t['creator_id']}, Status: {$t['status_id']}\n";
        }
        exit;
    }
    
    echo "✅ 任務存在:\n";
    echo "  - ID: {$task['id']}\n";
    echo "  - Title: {$task['title']}\n";
    echo "  - Creator ID: {$task['creator_id']}\n";
    echo "  - Participant ID: {$task['participant_id']}\n";
    echo "  - Status Code: {$task['status_code']}\n";
    echo "  - Status Display: {$task['status_display']}\n";
    echo "  - Created: {$task['created_at']}\n\n";
    
    // 2. 檢查創建者權限
    echo "2. 檢查創建者權限:\n";
    if ((int)$task['creator_id'] === $creatorId) {
        echo "✅ 用戶 $creatorId 是任務的創建者\n";
    } else {
        echo "❌ 用戶 $creatorId 不是任務的創建者 (實際創建者: {$task['creator_id']})\n";
    }
    echo "\n";
    
    // 3. 檢查任務狀態
    echo "3. 檢查任務狀態:\n";
    if ($task['status_code'] === 'open') {
        echo "✅ 任務狀態為 'open'，可以接受應徵\n";
    } else {
        echo "❌ 任務狀態為 '{$task['status_code']}'，不能接受應徵 (需要 'open' 狀態)\n";
    }
    echo "\n";
    
    // 4. 檢查應徵記錄
    echo "4. 檢查應徵記錄:\n";
    $applications = $db->fetchAll(
        "SELECT ta.*, u.name AS user_name 
         FROM task_applications ta 
         LEFT JOIN users u ON ta.user_id = u.id 
         WHERE ta.task_id = ?",
        [$taskId]
    );
    
    if (empty($applications)) {
        echo "❌ 沒有找到任務 '$taskId' 的應徵記錄\n";
    } else {
        echo "✅ 找到 " . count($applications) . " 個應徵記錄:\n";
        foreach ($applications as $app) {
            echo "  - Application ID: {$app['id']}\n";
            echo "    User ID: {$app['user_id']} ({$app['user_name']})\n";
            echo "    Status: {$app['status']}\n";
            echo "    Created: {$app['created_at']}\n";
            echo "    Updated: {$app['updated_at']}\n\n";
        }
    }
    
    // 5. 檢查目標用戶是否存在
    echo "5. 檢查目標用戶:\n";
    $targetUser = $db->fetch("SELECT id, name, email FROM users WHERE id = ?", [$participantId]);
    if (!$targetUser) {
        echo "❌ 用戶 ID $participantId 不存在\n";
    } else {
        echo "✅ 目標用戶存在:\n";
        echo "  - ID: {$targetUser['id']}\n";
        echo "  - Name: {$targetUser['name']}\n";
        echo "  - Email: {$targetUser['email']}\n";
    }
    echo "\n";
    
    // 6. 檢查聊天室
    echo "6. 檢查聊天室:\n";
    $chatRoom = $db->fetch(
        "SELECT * FROM chat_rooms WHERE task_id = ? AND (creator_id = ? OR participant_id = ?)",
        [$taskId, $creatorId, $participantId]
    );
    
    if (!$chatRoom) {
        echo "❌ 沒有找到相關的聊天室\n";
    } else {
        echo "✅ 找到聊天室:\n";
        echo "  - Room ID: {$chatRoom['id']}\n";
        echo "  - Creator ID: {$chatRoom['creator_id']}\n";
        echo "  - Participant ID: {$chatRoom['participant_id']}\n";
        echo "  - Type: {$chatRoom['type']}\n";
    }
    echo "\n";
    
    // 7. 檢查任務狀態表
    echo "7. 檢查任務狀態表:\n";
    $statuses = $db->fetchAll("SELECT * FROM task_statuses ORDER BY id");
    foreach ($statuses as $status) {
        echo "  - ID: {$status['id']}, Code: {$status['code']}, Display: {$status['display_name']}\n";
    }
    
} catch (Exception $e) {
    echo "❌ 錯誤: " . $e->getMessage() . "\n";
    echo "Stack trace: " . $e->getTraceAsString() . "\n";
}
?>
