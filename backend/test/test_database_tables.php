<?php
/**
 * 測試資料庫表結構
 */

try {
    // 使用 MAMP socket 連接
    $dsn = "mysql:unix_socket=/Applications/MAMP/tmp/mysql/mysql.sock;dbname=hero4helpdemofhs_hero4help;charset=utf8mb4";
    $pdo = new PDO($dsn, 'root', 'root', [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    
    echo "Database connected successfully.\n\n";
    
    // 檢查所有相關表
    $tables = [
        'task_completion_points_fee_settings',
        'point_transactions',
        'fee_revenue_ledger',
        'user_active_log',
        'tasks',
        'task_statuses',
        'users',
        'chat_rooms',
        'chat_messages'
    ];
    
    foreach ($tables as $table) {
        echo "=== Checking table: $table ===\n";
        
        try {
            $stmt = $pdo->query("SHOW TABLES LIKE '$table'");
            $exists = $stmt->fetch();
            
            if ($exists) {
                echo "✅ Table exists\n";
                
                // 顯示表結構
                $columns = $pdo->query("DESCRIBE $table")->fetchAll();
                echo "Columns:\n";
                foreach ($columns as $column) {
                    echo "  - {$column['Field']}: {$column['Type']} " . ($column['Null'] === 'NO' ? 'NOT NULL' : 'NULL') . "\n";
                }
                
                // 顯示記錄數
                $count = $pdo->query("SELECT COUNT(*) as count FROM $table")->fetch();
                echo "Records: {$count['count']}\n";
                
            } else {
                echo "❌ Table does not exist\n";
            }
            
        } catch (Exception $e) {
            echo "❌ Error checking table: " . $e->getMessage() . "\n";
        }
        
        echo "\n";
    }
    
    // 測試點數轉移相關的查詢
    echo "=== Testing Point Transfer Queries ===\n";
    
    // 檢查用戶點數
    $stmt = $pdo->query("SELECT id, name, points FROM users LIMIT 3");
    $users = $stmt->fetchAll();
    
    echo "Sample users:\n";
    foreach ($users as $user) {
        echo "  - ID: {$user['id']}, Name: {$user['name']}, Points: {$user['points']}\n";
    }
    
    // 檢查任務狀態
    $stmt = $pdo->query("SELECT id, code, display_name FROM task_statuses");
    $statuses = $stmt->fetchAll();
    
    echo "\nTask statuses:\n";
    foreach ($statuses as $status) {
        echo "  - ID: {$status['id']}, Code: {$status['code']}, Name: {$status['display_name']}\n";
    }
    
    echo "\n✅ Database structure test completed successfully!\n";
    
} catch (Exception $e) {
    echo "❌ Test failed with exception: " . $e->getMessage() . "\n";
    echo "Stack trace:\n" . $e->getTraceAsString() . "\n";
}
?>
