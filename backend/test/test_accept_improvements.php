<?php
/**
 * 測試 Accept API 的改進功能
 * 測試重複 Accept 檢查和錯誤處理
 */

require_once __DIR__ . '/../config/database.php';

try {
    $db = Database::getInstance();
    
    echo "=== 測試 Accept API 改進功能 ===\n\n";
    
    // 1. 測試重複 Accept 同一個用戶
    echo "1. 測試重複 Accept 同一個用戶:\n";
    $taskId = 'test-posted-2005-pending';
    $creatorId = 2;
    $participantId = 1;
    
    // 檢查當前任務狀態
    $task = $db->fetch(
        "SELECT t.*, s.code AS status_code, s.display_name AS status_display 
         FROM tasks t 
         LEFT JOIN task_statuses s ON t.status_id = s.id 
         WHERE t.id = ?",
        [$taskId]
    );
    
    if ($task) {
        echo "任務狀態: {$task['status_code']} ({$task['status_display']})\n";
        echo "參與者: {$task['participant_id']}\n";
        
        if ($task['participant_id'] == $participantId) {
            echo "✅ 預期結果: 應該返回 'This user has already been assigned as the tasker' 錯誤\n";
        } else {
            echo "❌ 任務沒有參與者，無法測試重複 Accept\n";
        }
    } else {
        echo "❌ 任務不存在\n";
    }
    echo "\n";
    
    // 2. 測試 Accept 其他用戶（當任務已有參與者時）
    echo "2. 測試 Accept 其他用戶（當任務已有參與者時）:\n";
    if ($task && $task['participant_id']) {
        $otherUserId = 3; // 假設用戶 3 存在
        $otherUser = $db->fetch("SELECT id, name FROM users WHERE id = ?", [$otherUserId]);
        
        if ($otherUser) {
            echo "嘗試將用戶 {$otherUser['name']} (ID: {$otherUser['id']}) 指派給已有參與者的任務\n";
            echo "✅ 預期結果: 應該返回 'This task already has an assigned tasker' 錯誤\n";
        } else {
            echo "❌ 用戶 ID $otherUserId 不存在，無法測試\n";
        }
    } else {
        echo "❌ 任務沒有參與者，無法測試此場景\n";
    }
    echo "\n";
    
    // 3. 測試非創建者嘗試 Accept
    echo "3. 測試非創建者嘗試 Accept:\n";
    if ($task) {
        $nonCreatorId = 1; // 假設用戶 1 不是創建者
        if ($task['creator_id'] != $nonCreatorId) {
            echo "用戶 ID $nonCreatorId 嘗試 Accept 創建者為 {$task['creator_id']} 的任務\n";
            echo "✅ 預期結果: 應該返回 'Only task creator can accept applications' 錯誤\n";
        } else {
            echo "❌ 用戶 ID $nonCreatorId 是創建者，無法測試此場景\n";
        }
    }
    echo "\n";
    
    // 4. 檢查應徵記錄狀態
    echo "4. 檢查應徵記錄狀態:\n";
    $applications = $db->fetchAll(
        "SELECT ta.*, u.name AS user_name 
         FROM task_applications ta 
         LEFT JOIN users u ON ta.user_id = u.id 
         WHERE ta.task_id = ?",
        [$taskId]
    );
    
    if (!empty($applications)) {
        foreach ($applications as $app) {
            echo "  - User: {$app['user_name']} (ID: {$app['user_id']})\n";
            echo "    Status: {$app['status']}\n";
            echo "    Application ID: {$app['id']}\n";
        }
    } else {
        echo "❌ 沒有找到應徵記錄\n";
    }
    echo "\n";
    
    // 5. 檢查聊天室狀態
    echo "5. 檢查聊天室狀態:\n";
    $chatRooms = $db->fetchAll(
        "SELECT * FROM chat_rooms WHERE task_id = ?",
        [$taskId]
    );
    
    if (!empty($chatRooms)) {
        foreach ($chatRooms as $room) {
            echo "  - Room ID: {$room['id']}\n";
            echo "    Creator: {$room['creator_id']}\n";
            echo "    Participant: {$room['participant_id']}\n";
            echo "    Type: {$room['type']}\n";
        }
    } else {
        echo "❌ 沒有找到聊天室\n";
    }
    echo "\n";
    
    echo "=== 測試完成 ===\n";
    echo "請使用以下 curl 命令測試 API:\n\n";
    
    echo "# 測試重複 Accept 同一個用戶:\n";
    echo "curl -X POST 'http://localhost/backend/api/tasks/applications/accept.php' \\\n";
    echo "  -H 'Content-Type: application/json' \\\n";
    echo "  -H 'Authorization: Bearer YOUR_TOKEN' \\\n";
    echo "  -d '{\"task_id\":\"$taskId\",\"user_id\":\"$participantId\",\"poster_id\":\"$creatorId\"}'\n\n";
    
    echo "# 測試 Accept 其他用戶:\n";
    echo "curl -X POST 'http://localhost/backend/api/tasks/applications/accept.php' \\\n";
    echo "  -H 'Content-Type: application/json' \\\n";
    echo "  -H 'Authorization: Bearer YOUR_TOKEN' \\\n";
    echo "  -d '{\"task_id\":\"$taskId\",\"user_id\":\"3\",\"poster_id\":\"$creatorId\"}'\n\n";
    
} catch (Exception $e) {
    echo "❌ 錯誤: " . $e->getMessage() . "\n";
    echo "Stack trace: " . $e->getTraceAsString() . "\n";
}
?>
