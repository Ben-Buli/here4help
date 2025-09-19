<?php
/**
 * MAMP 資料庫連線測試檔案
 * 詳細測試 MAMP 環境下的資料庫連線
 */

echo "=== MAMP 資料庫連線詳細測試 ===\n";
echo "測試時間: " . date('Y-m-d H:i:s') . "\n\n";

// 1. 檢查 MAMP 環境
echo "1. 檢查 MAMP 環境...\n";
if (file_exists('/Applications/MAMP/tmp/mysql/mysql.sock')) {
    echo "✅ MAMP MySQL Socket 存在\n";
} else {
    echo "❌ MAMP MySQL Socket 不存在\n";
    exit(1);
}

// 2. 測試不同的連線方式
echo "\n2. 測試不同的連線方式...\n";

$host = 'localhost';
$port = '8889';
$dbname = 'hero4helpdemofhs_hero4help';
$username = 'root';
$password = 'root';

// 方式 1: 使用 Socket 連線
echo "\n2.1 測試 Socket 連線...\n";
try {
    $dsn_socket = "mysql:unix_socket=/Applications/MAMP/tmp/mysql/mysql.sock;dbname=$dbname;charset=utf8mb4";
    $pdo_socket = new PDO($dsn_socket, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    echo "✅ Socket 連線成功！\n";
    
    // 測試查詢
    $result = $pdo_socket->query("SELECT COUNT(*) as count FROM users")->fetch();
    echo "✅ 用戶表查詢成功，用戶數量: " . $result['count'] . "\n";
    
} catch (PDOException $e) {
    echo "❌ Socket 連線失敗: " . $e->getMessage() . "\n";
}

// 方式 2: 使用 TCP 連線
echo "\n2.2 測試 TCP 連線...\n";
try {
    $dsn_tcp = "mysql:host=$host;port=$port;dbname=$dbname;charset=utf8mb4";
    $pdo_tcp = new PDO($dsn_tcp, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    echo "✅ TCP 連線成功！\n";
    
    // 測試查詢
    $result = $pdo_tcp->query("SELECT COUNT(*) as count FROM users")->fetch();
    echo "✅ 用戶表查詢成功，用戶數量: " . $result['count'] . "\n";
    
} catch (PDOException $e) {
    echo "❌ TCP 連線失敗: " . $e->getMessage() . "\n";
}

// 方式 3: 使用 127.0.0.1
echo "\n2.3 測試 127.0.0.1 連線...\n";
try {
    $dsn_127 = "mysql:host=127.0.0.1;port=$port;dbname=$dbname;charset=utf8mb4";
    $pdo_127 = new PDO($dsn_127, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    echo "✅ 127.0.0.1 連線成功！\n";
    
    // 測試查詢
    $result = $pdo_127->query("SELECT COUNT(*) as count FROM users")->fetch();
    echo "✅ 用戶表查詢成功，用戶數量: " . $result['count'] . "\n";
    
} catch (PDOException $e) {
    echo "❌ 127.0.0.1 連線失敗: " . $e->getMessage() . "\n";
}

// 3. 測試 Backend 載入器
echo "\n3. 測試 Backend 載入器...\n";
try {
    require_once 'backend/config/env_loader.php';
    
    echo "   - APP_ENVIRONMENT: " . EnvLoader::get('APP_ENVIRONMENT') . "\n";
    echo "   - DB_HOST: " . EnvLoader::get('DB_HOST') . "\n";
    echo "   - DB_PORT: " . EnvLoader::get('DB_PORT') . "\n";
    echo "   - DB_NAME: " . EnvLoader::get('DB_NAME') . "\n";
    echo "   - DB_USERNAME: " . EnvLoader::get('DB_USERNAME') . "\n";
    
    // 測試 Backend 資料庫連線
    require_once 'backend/config/database.php';
    $db = Database::getInstance();
    echo "✅ Backend 資料庫連線成功！\n";
    
    // 測試查詢
    $result = $db->fetch("SELECT COUNT(*) as count FROM users");
    echo "✅ Backend 用戶表查詢成功，用戶數量: " . $result['count'] . "\n";
    
} catch (Exception $e) {
    echo "❌ Backend 資料庫連線失敗: " . $e->getMessage() . "\n";
}

// 4. 檢查資料庫表結構
echo "\n4. 檢查資料庫表結構...\n";
try {
    $pdo = new PDO("mysql:unix_socket=/Applications/MAMP/tmp/mysql/mysql.sock;dbname=$dbname;charset=utf8mb4", $username, $password);
    
    $tables = $pdo->query("SHOW TABLES")->fetchAll(PDO::FETCH_COLUMN);
    echo "✅ 資料庫表數量: " . count($tables) . "\n";
    
    if (in_array('users', $tables)) {
        echo "✅ users 表存在\n";
        
        // 檢查 users 表結構
        $columns = $pdo->query("DESCRIBE users")->fetchAll(PDO::FETCH_ASSOC);
        echo "✅ users 表欄位數量: " . count($columns) . "\n";
        
        // 檢查用戶數量
        $count = $pdo->query("SELECT COUNT(*) as count FROM users")->fetch();
        echo "✅ users 表記錄數量: " . $count['count'] . "\n";
    } else {
        echo "❌ users 表不存在\n";
    }
    
} catch (PDOException $e) {
    echo "❌ 資料庫表結構檢查失敗: " . $e->getMessage() . "\n";
}

echo "\n=== 測試完成 ===\n";
echo "📋 建議:\n";
echo "1. 如果 Socket 連線成功，建議使用 Socket 連線\n";
echo "2. 如果 TCP 連線成功，可以使用 TCP 連線\n";
echo "3. 如果 Backend 連線成功，環境配置正確\n";
echo "4. 如果所有連線都失敗，請檢查 MAMP 設定\n";
?>
