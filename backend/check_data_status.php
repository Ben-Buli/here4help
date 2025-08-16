<?php
/**
 * 檢查資料庫狀態腳本
 */

require_once 'config/database.php';

try {
    $db = Database::getInstance();
    
    echo "🔍 檢查資料庫狀態...\n\n";
    
    // 檢查使用者
    echo "👥 使用者資料：\n";
    $users = $db->fetchAll("SELECT id, name, email, created_at FROM users ORDER BY id");
    foreach ($users as $user) {
        echo "  ID {$user['id']}: {$user['name']} ({$user['email']}) - {$user['created_at']}\n";
    }
    
    echo "\n📋 任務資料：\n";
    $tasks = $db->fetchAll("SELECT id, title, creator_id, status_id, created_at FROM tasks ORDER BY created_at");
    foreach ($tasks as $task) {
        echo "  {$task['id']}: {$task['title']} (創建者: {$task['creator_id']}, 狀態: {$task['status_id']}) - {$task['created_at']}\n";
    }
    
    echo "\n📝 應徵記錄：\n";
    $applications = $db->fetchAll("SELECT id, task_id, user_id, status, created_at FROM task_applications ORDER BY created_at");
    foreach ($applications as $app) {
        echo "  ID {$app['id']}: 任務 {$app['task_id']}, 應徵者 {$app['user_id']}, 狀態 {$app['status']} - {$app['created_at']}\n";
    }
    
    echo "\n💬 聊天室：\n";
    $rooms = $db->fetchAll("SELECT id, task_id, creator_id, participant_id, type, created_at FROM chat_rooms ORDER BY created_at");
    foreach ($rooms as $room) {
        echo "  ID {$room['id']}: 任務 {$room['task_id']}, 創建者 {$room['creator_id']}, 參與者 {$room['participant_id']}, 類型 {$room['type']} - {$room['created_at']}\n";
    }
    
    echo "\n💬 聊天訊息：\n";
    $messages = $db->fetchAll("SELECT id, room_id, from_user_id, LEFT(content, 50) as content_preview, created_at FROM chat_messages ORDER BY created_at");
    foreach ($messages as $msg) {
        $preview = $msg['content_preview'] . (strlen($msg['content_preview']) >= 50 ? '...' : '');
        echo "  ID {$msg['id']}: 聊天室 {$msg['room_id']}, 發送者 {$msg['from_user_id']}, 內容: {$preview} - {$msg['created_at']}\n";
    }
    
    echo "\n📊 統計摘要：\n";
    echo "- 使用者總數: " . $db->fetch("SELECT COUNT(*) as count FROM users")['count'] . "\n";
    echo "- 任務總數: " . $db->fetch("SELECT COUNT(*) as count FROM tasks")['count'] . "\n";
    echo "- 應徵記錄總數: " . $db->fetch("SELECT COUNT(*) as count FROM task_applications")['count'] . "\n";
    echo "- 聊天室總數: " . $db->fetch("SELECT COUNT(*) as count FROM chat_rooms")['count'] . "\n";
    echo "- 聊天訊息總數: " . $db->fetch("SELECT COUNT(*) as count FROM chat_messages")['count'] . "\n";
    
    // 檢查 users.id = 2 的詳細資料
    echo "\n🎯 使用者 ID = 2 的詳細資料：\n";
    $user2 = $db->fetch("SELECT * FROM users WHERE id = 2");
    if ($user2) {
        echo "  使用者: {$user2['name']} ({$user2['email']})\n";
        
        // 檢查發布的任務
        $myTasks = $db->fetchAll("SELECT * FROM tasks WHERE creator_id = 2");
        echo "  發布的任務數量: " . count($myTasks) . "\n";
        foreach ($myTasks as $task) {
            echo "    - {$task['title']} (狀態: {$task['status_id']})\n";
        }
        
        // 檢查應徵的任務
        $myApplications = $db->fetchAll("SELECT ta.*, t.title as task_title FROM task_applications ta JOIN tasks t ON ta.task_id = t.id WHERE ta.user_id = 2");
        echo "  應徵的任務數量: " . count($myApplications) . "\n";
        foreach ($myApplications as $app) {
            // 通過 task_id 和 user_id 查找對應的聊天室
            $roomInfo = $db->fetch("SELECT id FROM chat_rooms WHERE task_id = ? AND (creator_id = ? OR participant_id = ?)", 
                [$app['task_id'], $app['user_id'], $app['user_id']]);
            $roomId = $roomInfo ? $roomInfo['id'] : 'N/A';
            echo "    - {$app['task_title']} (狀態: {$app['status']}, 聊天室: {$roomId})\n";
        }
        
        // 檢查參與的聊天室
        $myRooms = $db->fetchAll("SELECT cr.*, t.title as task_title FROM chat_rooms cr JOIN tasks t ON cr.task_id = t.id WHERE cr.creator_id = 2 OR cr.participant_id = 2");
        echo "  參與的聊天室數量: " . count($myRooms) . "\n";
        foreach ($myRooms as $room) {
            $role = $room['creator_id'] == 2 ? '創建者' : '參與者';
            echo "    - {$room['task_title']} (角色: {$role}, 聊天室ID: {$room['id']})\n";
        }
    } else {
        echo "  ❌ 使用者 ID = 2 不存在\n";
    }
    
} catch (Exception $e) {
    echo "❌ 錯誤: " . $e->getMessage() . "\n";
}
?> 