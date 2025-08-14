<?php
/**
 * 檢查資料表結構腳本
 */

require_once 'config/database.php';

try {
    $db = Database::getInstance();
    
    echo "🔍 檢查資料表結構...\n\n";
    
    // 檢查 tasks 表結構
    echo "📋 tasks 表結構：\n";
    $columns = $db->fetchAll("SHOW COLUMNS FROM tasks");
    foreach ($columns as $column) {
        echo "  {$column['Field']} - {$column['Type']} - {$column['Null']} - {$column['Key']} - {$column['Default']}\n";
    }
    
    echo "\n📝 task_applications 表結構：\n";
    $columns = $db->fetchAll("SHOW COLUMNS FROM task_applications");
    foreach ($columns as $column) {
        echo "  {$column['Field']} - {$column['Type']} - {$column['Null']} - {$column['Key']} - {$column['Default']}\n";
    }
    
    echo "\n💬 chat_rooms 表結構：\n";
    $columns = $db->fetchAll("SHOW COLUMNS FROM chat_rooms");
    foreach ($columns as $column) {
        echo "  {$column['Field']} - {$column['Type']} - {$column['Null']} - {$column['Key']} - {$column['Default']}\n";
    }
    
    echo "\n💬 chat_messages 表結構：\n";
    $columns = $db->fetchAll("SHOW COLUMNS FROM chat_messages");
    foreach ($columns as $column) {
        echo "  {$column['Field']} - {$column['Type']} - {$column['Null']} - {$column['Key']} - {$column['Default']}\n";
    }
    
    echo "\n👥 users 表結構：\n";
    $columns = $db->fetchAll("SHOW COLUMNS FROM users");
    foreach ($columns as $column) {
        echo "  {$column['Field']} - {$column['Type']} - {$column['Null']} - {$column['Key']} - {$column['Default']}\n";
    }
    
} catch (Exception $e) {
    echo "❌ 錯誤: " . $e->getMessage() . "\n";
}
?> 