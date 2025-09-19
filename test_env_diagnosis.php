<?php
/**
 * 環境變數診斷檔案
 * 用於診斷環境變數載入問題
 */

echo "=== Here4Help 環境變數診斷 ===\n";
echo "診斷時間: " . date('Y-m-d H:i:s') . "\n\n";

// 1. 檢查檔案存在性
echo "1. 檢查環境配置檔案...\n";
$envFiles = [
    '/env/production.env' => '統一環境配置',
    '/backend/.env' => 'Backend 專用配置',
    '/.env' => '根目錄配置',
    '/backend/config/env.development' => 'Backend 開發配置'
];

foreach ($envFiles as $file => $desc) {
    $fullPath = __DIR__ . $file;
    if (file_exists($fullPath)) {
        echo "✅ $desc ($file): 存在\n";
    } else {
        echo "❌ $desc ($file): 不存在\n";
    }
}

// 2. 測試不同的環境載入器
echo "\n2. 測試環境載入器...\n";

// 測試統一載入器
echo "\n2.1 測試統一載入器 (/env/env_loader.php)...\n";
try {
    require_once 'env/env_loader.php';
    echo "✅ 統一載入器載入成功\n";
    echo "   APP_ENVIRONMENT: " . EnvLoader::get('APP_ENVIRONMENT') . "\n";
    echo "   DB_HOST: " . EnvLoader::get('DB_HOST') . "\n";
    echo "   DB_NAME: " . EnvLoader::get('DB_NAME') . "\n";
} catch (Exception $e) {
    echo "❌ 統一載入器載入失敗: " . $e->getMessage() . "\n";
}

// 測試 Backend 載入器
echo "\n2.2 測試 Backend 載入器 (/backend/config/env_loader.php)...\n";
try {
    require_once 'backend/config/env_loader.php';
    echo "✅ Backend 載入器載入成功\n";
    echo "   APP_ENVIRONMENT: " . EnvLoader::get('APP_ENVIRONMENT') . "\n";
    echo "   DB_HOST: " . EnvLoader::get('DB_HOST') . "\n";
    echo "   DB_NAME: " . EnvLoader::get('DB_NAME') . "\n";
    echo "   DB_USERNAME: " . EnvLoader::get('DB_USERNAME') . "\n";
    echo "   DB_PASSWORD: " . (EnvLoader::get('DB_PASSWORD') ? '已設定' : '未設定') . "\n";
} catch (Exception $e) {
    echo "❌ Backend 載入器載入失敗: " . $e->getMessage() . "\n";
}

// 3. 檢查環境變數載入順序
echo "\n3. 檢查環境變數載入順序...\n";
echo "Backend 載入器載入順序:\n";
echo "1. 優先: /env/production.env\n";
echo "2. 回退: /backend/.env\n";
echo "3. 最後: /.env\n";

// 4. 手動測試資料庫連線
echo "\n4. 手動測試資料庫連線...\n";
try {
    require_once 'backend/config/env_loader.php';
    
    $host = EnvLoader::get('DB_HOST');
    $port = EnvLoader::get('DB_PORT');
    $dbname = EnvLoader::get('DB_NAME');
    $username = EnvLoader::get('DB_USERNAME');
    $password = EnvLoader::get('DB_PASSWORD');
    
    echo "連線參數:\n";
    echo "  Host: $host\n";
    echo "  Port: $port\n";
    echo "  Database: $dbname\n";
    echo "  Username: $username\n";
    echo "  Password: " . ($password ? '已設定' : '未設定') . "\n";
    
    // 嘗試連線
    $dsn = "mysql:host=$host;port=$port;dbname=$dbname;charset=utf8mb4";
    $pdo = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    
    echo "✅ 手動資料庫連線成功！\n";
    
} catch (PDOException $e) {
    echo "❌ 手動資料庫連線失敗: " . $e->getMessage() . "\n";
    
    // 提供解決建議
    echo "\n=== 解決建議 ===\n";
    echo "1. 檢查資料庫用戶名和密碼是否正確\n";
    echo "2. 確認資料庫服務是否運行\n";
    echo "3. 檢查資料庫用戶權限\n";
    echo "4. 確認資料庫名稱是否存在\n";
}

// 5. 檢查 MAMP 環境
echo "\n5. 檢查 MAMP 環境...\n";
if (file_exists('/Applications/MAMP/tmp/mysql/mysql.sock')) {
    echo "✅ 檢測到 MAMP 環境\n";
    echo "建議使用 MAMP 的資料庫設定:\n";
    echo "  DB_HOST: localhost\n";
    echo "  DB_PORT: 8889\n";
    echo "  DB_USERNAME: root\n";
    echo "  DB_PASSWORD: root\n";
} else {
    echo "⚠️ 未檢測到 MAMP 環境\n";
}

echo "\n=== 診斷完成 ===\n";
?>
