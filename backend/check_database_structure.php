<?php
/**
 * 資料庫結構檢查腳本
 * 用於診斷 Posted Tasks 和 My Works 的問題
 */

require_once 'config/database.php';

try {
    $db = Database::getInstance();
    
    echo "🔍 檢查資料庫結構...\n\n";
    
    // 1. 檢查 tasks 表
    echo "📋 檢查 tasks 表:\n";
    try {
        $result = $db->fetchAll("DESCRIBE tasks");
        foreach ($result as $row) {
            echo "  - {$row['Field']}: {$row['Type']} {$row['Null']} {$row['Key']} {$row['Default']}\n";
        }
    } catch (Exception $e) {
        echo "  ❌ 無法讀取 tasks 表: " . $e->getMessage() . "\n";
    }
    
    echo "\n";
    
    // 2. 檢查 task_applications 表
    echo "📋 檢查 task_applications 表:\n";
    try {
        $result = $db->fetchAll("DESCRIBE task_applications");
        foreach ($result as $row) {
            echo "  - {$row['Field']}: {$row['Type']} {$row['Null']} {$row['Key']} {$row['Default']}\n";
        }
    } catch (Exception $e) {
        echo "  ❌ 無法讀取 task_applications 表: " . $e->getMessage() . "\n";
    }
    
    echo "\n";
    
    // 3. 檢查 users 表
    echo "📋 檢查 users 表:\n";
    try {
        $result = $db->fetchAll("DESCRIBE users");
        foreach ($result as $row) {
            echo "  - {$row['Field']}: {$row['Type']} {$row['Null']} {$row['Key']} {$row['Default']}\n";
        }
    } catch (Exception $e) {
        echo "  ❌ 無法讀取 users 表: " . $e->getMessage() . "\n";
    }
    
    echo "\n";
    
    // 4. 檢查 chat_messages 表
    echo "📋 檢查 chat_messages 表:\n";
    try {
        $result = $db->fetchAll("DESCRIBE chat_messages");
        foreach ($result as $row) {
            echo "  - {$row['Field']}: {$row['Type']} {$row['Null']} {$row['Key']} {$row['Default']}\n";
        }
    } catch (Exception $e) {
        echo "  ❌ 無法讀取 chat_messages 表: " . $e->getMessage() . "\n";
    }
    
    echo "\n";
    
    // 5. 檢查資料數量
    echo "📊 檢查資料數量:\n";
    try {
        $tasksCount = $db->fetch("SELECT COUNT(*) as count FROM tasks")['count'];
        echo "  - tasks 表: $tasksCount 筆資料\n";
        
        $applicationsCount = $db->fetch("SELECT COUNT(*) as count FROM task_applications")['count'];
        echo "  - task_applications 表: $applicationsCount 筆資料\n";
        
        $usersCount = $db->fetch("SELECT COUNT(*) as count FROM users")['count'];
        echo "  - users 表: $usersCount 筆資料\n";
        
        try {
            $messagesCount = $db->fetch("SELECT COUNT(*) as count FROM chat_messages")['count'];
            echo "  - chat_messages 表: $messagesCount 筆資料\n";
        } catch (Exception $e) {
            echo "  - chat_messages 表: 無法讀取\n";
        }
    } catch (Exception $e) {
        echo "  ❌ 無法讀取資料數量: " . $e->getMessage() . "\n";
    }
    
    echo "\n";
    
    // 5. 檢查特定用戶的資料
    echo "👤 檢查測試用戶資料:\n";
    try {
        $testUser = $db->fetch("SELECT id, name, email FROM users LIMIT 1");
        if ($testUser) {
            echo "  - 測試用戶: ID={$testUser['id']}, 名稱={$testUser['name']}, 郵箱={$testUser['email']}\n";
            
            // 檢查該用戶發布的任務
            $postedTasks = $db->fetchAll("SELECT id, title, status_id FROM tasks WHERE creator_id = ?", [$testUser['id']]);
            echo "  - 發布的任務: " . count($postedTasks) . " 筆\n";
            
            // 檢查該用戶的應徵記錄
            $applications = $db->fetchAll("SELECT ta.id, ta.task_id, ta.status, t.title FROM task_applications ta JOIN tasks t ON ta.task_id = t.id WHERE ta.user_id = ?", [$testUser['id']]);
            echo "  - 應徵記錄: " . count($applications) . " 筆\n";
        } else {
            echo "  ❌ 沒有找到用戶資料\n";
        }
    } catch (Exception $e) {
        echo "  ❌ 無法檢查用戶資料: " . $e->getMessage() . "\n";
    }
    
    echo "\n✅ 資料庫結構檢查完成\n";
    
} catch (Exception $e) {
    echo "❌ 檢查失敗: " . $e->getMessage() . "\n";
}
?>
