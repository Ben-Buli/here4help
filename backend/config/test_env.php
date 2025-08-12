<?php
/**
 * 環境變數配置測試腳本
 * 用於驗證 .env 檔案載入是否正常
 */

require_once __DIR__ . '/env_loader.php';

echo "=== Here4Help 環境變數配置測試 ===\n\n";

try {
    // 載入環境變數
    EnvLoader::load();
    echo "✅ 環境變數載入成功\n\n";
    
    // 測試基本配置
    echo "📋 基本配置:\n";
    echo "APP_ENV: " . EnvLoader::get('APP_ENV', 'not_set') . "\n";
    echo "APP_DEBUG: " . EnvLoader::get('APP_DEBUG', 'not_set') . "\n";
    echo "\n";
    
    // 測試資料庫配置
    echo "📋 資料庫配置:\n";
    $dbConfig = EnvLoader::getDatabaseConfig();
    echo "Host: " . $dbConfig['host'] . "\n";
    echo "Port: " . $dbConfig['port'] . "\n";
    echo "Database: " . $dbConfig['dbname'] . "\n";
    echo "Username: " . $dbConfig['username'] . "\n";
    echo "Password: " . (empty($dbConfig['password']) ? '未設定' : '已設定 (' . strlen($dbConfig['password']) . ' 字元)') . "\n";
    echo "Charset: " . $dbConfig['charset'] . "\n";
    echo "\n";
    
    // 測試 Socket 配置
    echo "📋 Socket.IO 配置:\n";
    echo "Host: " . EnvLoader::get('SOCKET_HOST', 'not_set') . "\n";
    echo "Port: " . EnvLoader::get('SOCKET_PORT', 'not_set') . "\n";
    echo "\n";
    
    // 測試 URL 配置
    echo "📋 應用程式 URL:\n";
    echo "開發環境: " . EnvLoader::get('DEV_BASE_URL', 'not_set') . "\n";
    echo "生產環境: " . EnvLoader::get('PROD_BASE_URL', 'not_set') . "\n";
    echo "\n";
    
    // 測試資料庫連線
    echo "🔗 測試資料庫連線...\n";
    require_once __DIR__ . '/database.php';
    
    $db = Database::getInstance();
    $result = $db->query("SELECT 1 as test")->fetch();
    
    if ($result && $result['test'] == 1) {
        echo "✅ 資料庫連線成功!\n";
    } else {
        echo "❌ 資料庫連線測試失敗\n";
    }
    
} catch (Exception $e) {
    echo "❌ 錯誤: " . $e->getMessage() . "\n";
    echo "\n📝 請檢查:\n";
    echo "1. .env 檔案是否存在於專案根目錄\n";
    echo "2. .env 檔案是否包含所有必要的配置\n";
    echo "3. 資料庫服務是否正在運行\n";
    echo "4. 資料庫連線資訊是否正確\n";
}

echo "\n=== 測試完成 ===\n";
?>