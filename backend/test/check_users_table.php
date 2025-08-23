<?php
require_once __DIR__ . '/../config/env_loader.php';

echo "=== 檢查 users 表結構 ===\n\n";

try {
    // 建立資料庫連線
    $dbHost = EnvLoader::get('DB_HOST');
    if ($dbHost === 'localhost') { $dbHost = '127.0.0.1'; }
    $dbPort = EnvLoader::get('DB_PORT') ?: '3306';
    $dsn = "mysql:host={$dbHost};port={$dbPort};dbname=" . EnvLoader::get('DB_NAME') . ";charset=utf8mb4";

    $pdo = new PDO(
        $dsn,
        EnvLoader::get('DB_USERNAME'),
        EnvLoader::get('DB_PASSWORD'),
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
        ]
    );
    
    // 查詢 users 表結構
    $stmt = $pdo->prepare("DESCRIBE users");
    $stmt->execute();
    $columns = $stmt->fetchAll();
    
    echo "users 表的欄位：\n";
    foreach ($columns as $column) {
        echo "- {$column['Field']} ({$column['Type']}) {$column['Null']} {$column['Default']}\n";
    }
    
    echo "\n檢查是否有測試用戶 (ID=1)：\n";
    $stmt = $pdo->prepare("SELECT id, name, email, created_at FROM users WHERE id = 1");
    $stmt->execute();
    $user = $stmt->fetch();
    
    if ($user) {
        echo "✅ 找到測試用戶：\n";
        echo "ID: {$user['id']}\n";
        echo "Name: {$user['name']}\n";
        echo "Email: {$user['email']}\n";
        echo "Created: {$user['created_at']}\n";
    } else {
        echo "❌ 未找到 ID=1 的用戶\n";
        
        // 查看前幾個用戶
        $stmt = $pdo->prepare("SELECT id, name, email FROM users LIMIT 3");
        $stmt->execute();
        $users = $stmt->fetchAll();
        
        if ($users) {
            echo "\n前幾個用戶：\n";
            foreach ($users as $u) {
                echo "ID: {$u['id']}, Name: {$u['name']}, Email: {$u['email']}\n";
            }
        }
    }
    
} catch (Exception $e) {
    echo "❌ 錯誤: " . $e->getMessage() . "\n";
}
?>
