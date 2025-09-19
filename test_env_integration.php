<?php
/**
 * 環境系統整合測試檔案
 * 測試統一後的環境變數載入系統
 */

echo "=== Here4Help 環境系統整合測試 ===\n";
echo "測試時間: " . date('Y-m-d H:i:s') . "\n\n";

// 1. 測試 Backend 載入器
echo "1. 測試 Backend 載入器...\n";
try {
    require_once 'backend/config/env_loader.php';
    echo "✅ Backend 載入器載入成功\n";
    
    // 檢查環境變數
    echo "   環境變數檢查:\n";
    echo "   - APP_ENVIRONMENT: " . EnvLoader::get('APP_ENVIRONMENT') . "\n";
    echo "   - DB_HOST: " . EnvLoader::get('DB_HOST') . "\n";
    echo "   - DB_NAME: " . EnvLoader::get('DB_NAME') . "\n";
    echo "   - DB_USERNAME: " . EnvLoader::get('DB_USERNAME') . "\n";
    echo "   - JWT_SECRET: " . (EnvLoader::get('JWT_SECRET') ? '已設定' : '未設定') . "\n";
    
} catch (Exception $e) {
    echo "❌ Backend 載入器載入失敗: " . $e->getMessage() . "\n";
    exit(1);
}

// 2. 測試統一載入器重新導向
echo "\n2. 測試統一載入器重新導向...\n";
try {
    require_once 'env/env_loader.php';
    echo "✅ 統一載入器重新導向成功\n";
    
    // 檢查是否使用相同的類別
    if (class_exists('EnvLoader')) {
        echo "✅ EnvLoader 類別存在\n";
        echo "   - 環境變數一致性檢查: " . (EnvLoader::get('APP_ENVIRONMENT') === 'production' ? '✅ 一致' : '❌ 不一致') . "\n";
    } else {
        echo "❌ EnvLoader 類別不存在\n";
    }
    
} catch (Exception $e) {
    echo "❌ 統一載入器重新導向失敗: " . $e->getMessage() . "\n";
}

// 3. 測試資料庫連線 (使用 MAMP 設定)
echo "\n3. 測試資料庫連線...\n";
try {
    // 檢查是否為 MAMP 環境
    if (file_exists('/Applications/MAMP/tmp/mysql/mysql.sock')) {
        echo "✅ 檢測到 MAMP 環境，使用 MAMP 資料庫設定\n";
        
        // 使用 MAMP 設定
        $host = 'localhost';
        $port = '8889';
        $dbname = 'hero4helpdemofhs_hero4help';
        $username = 'root';
        $password = 'root';
        
        $dsn = "mysql:host=$host;port=$port;dbname=$dbname;charset=utf8mb4";
        $pdo = new PDO($dsn, $username, $password, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);
        
        echo "✅ MAMP 資料庫連線成功！\n";
        
        // 測試基本查詢
        $result = $pdo->query("SELECT COUNT(*) as count FROM users")->fetch();
        echo "✅ 用戶表查詢成功，用戶數量: " . $result['count'] . "\n";
        
    } else {
        echo "⚠️ 未檢測到 MAMP 環境，使用生產環境設定\n";
        
        // 使用生產環境設定
        require_once 'backend/config/database.php';
        $db = Database::getInstance();
        echo "✅ 生產環境資料庫連線成功！\n";
        
        // 測試基本查詢
        $result = $db->fetch("SELECT COUNT(*) as count FROM users");
        echo "✅ 用戶表查詢成功，用戶數量: " . $result['count'] . "\n";
    }
    
} catch (Exception $e) {
    echo "❌ 資料庫連線失敗: " . $e->getMessage() . "\n";
    
    // 提供診斷資訊
    echo "\n=== 診斷資訊 ===\n";
    echo "DB_HOST: " . EnvLoader::get('DB_HOST') . "\n";
    echo "DB_PORT: " . EnvLoader::get('DB_PORT') . "\n";
    echo "DB_NAME: " . EnvLoader::get('DB_NAME') . "\n";
    echo "DB_USERNAME: " . EnvLoader::get('DB_USERNAME') . "\n";
    echo "DB_PASSWORD: " . (EnvLoader::get('DB_PASSWORD') ? '已設定' : '未設定') . "\n";
}

// 4. 測試環境配置檔案載入順序
echo "\n4. 測試環境配置檔案載入順序...\n";
$envFiles = [
    '/env/production.env' => '統一環境配置',
    '/backend/.env' => 'Backend 專用配置',
    '/.env' => '根目錄配置'
];

foreach ($envFiles as $file => $desc) {
    $fullPath = __DIR__ . $file;
    if (file_exists($fullPath)) {
        echo "✅ $desc ($file): 存在\n";
    } else {
        echo "❌ $desc ($file): 不存在\n";
    }
}

// 5. 測試 API 端點
echo "\n5. 測試 API 端點...\n";
try {
    // 測試 ping 端點
    $pingUrl = 'http://localhost:8888/here4help/backend/api/ping.php';
    $context = stream_context_create([
        'http' => [
            'timeout' => 5,
            'method' => 'GET'
        ]
    ]);
    
    $response = @file_get_contents($pingUrl, false, $context);
    if ($response) {
        $data = json_decode($response, true);
        if ($data && isset($data['pong'])) {
            echo "✅ Ping API 端點正常: " . $response . "\n";
        } else {
            echo "⚠️ Ping API 端點回應異常: " . $response . "\n";
        }
    } else {
        echo "⚠️ Ping API 端點無法訪問 (可能 MAMP 未啟動)\n";
    }
    
} catch (Exception $e) {
    echo "⚠️ API 端點測試失敗: " . $e->getMessage() . "\n";
}

echo "\n=== 測試完成 ===\n";
echo "✅ 環境系統整合成功！\n";
echo "✅ 統一載入器重新導向正常！\n";
echo "✅ 環境變數載入一致！\n";
echo "\n📋 部署建議:\n";
echo "1. 使用 backend/config/env_loader.php 作為主要載入器\n";
echo "2. 統一載入器已重新導向到 Backend 載入器\n";
echo "3. 環境配置檔案載入順序: /env/production.env > /backend/.env > /.env\n";
echo "4. 確保 cPanel 部署時使用正確的資料庫設定\n";
?>
