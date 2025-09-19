<?php
/**
 * 統一環境系統測試檔案
 * 測試整合後的環境變數載入系統
 */

echo "=== Here4Help 統一環境系統測試 ===\n";
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

// 2. 測試統一載入器 (應該重新導向到 Backend 載入器)
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

// 3. 測試資料庫連線
echo "\n3. 測試資料庫連線...\n";
try {
    require_once 'backend/config/database.php';
    $db = Database::getInstance();
    echo "✅ 資料庫連線成功！\n";
    
    // 測試基本查詢
    $result = $db->fetch("SELECT COUNT(*) as count FROM users");
    echo "✅ 用戶表查詢成功，用戶數量: " . $result['count'] . "\n";
    
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

// 4. 測試 JWT 功能
echo "\n4. 測試 JWT 功能...\n";
try {
    require_once 'backend/utils/JWTManager.php';
    $jwtManager = new JWTManager();
    
    // 測試 JWT 生成
    $testPayload = ['user_id' => 1, 'email' => 'test@example.com'];
    $token = $jwtManager->generateAccessToken($testPayload);
    
    if ($token) {
        echo "✅ JWT Token 生成成功\n";
        
        // 測試 JWT 驗證
        $decoded = $jwtManager->validateToken($token);
        if ($decoded && $decoded['user_id'] == 1) {
            echo "✅ JWT Token 驗證成功\n";
        } else {
            echo "❌ JWT Token 驗證失敗\n";
        }
    } else {
        echo "❌ JWT Token 生成失敗\n";
    }
} catch (Exception $e) {
    echo "❌ JWT 功能測試失敗: " . $e->getMessage() . "\n";
}

// 5. 測試環境配置檔案載入順序
echo "\n5. 測試環境配置檔案載入順序...\n";
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

echo "\n=== 測試完成 ===\n";
echo "如果所有測試都通過，統一環境系統已準備就緒！\n";
?>
