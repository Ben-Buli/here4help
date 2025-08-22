<?php
/**
 * 環境配置檢查腳本
 * 用於診斷 JWT 和資料庫配置問題
 */

echo "🔍 開始環境配置檢查...\n\n";

// 檢查 1：環境變數
echo "📋 檢查 1：環境變數\n";
$envVars = [
    'JWT_SECRET' => getenv('JWT_SECRET'),
    'DB_HOST' => getenv('DB_HOST'),
    'DB_PORT' => getenv('DB_PORT'),
    'DB_NAME' => getenv('DB_NAME'),
    'DB_USERNAME' => getenv('DB_USERNAME'),
    'DB_PASSWORD' => getenv('DB_PASSWORD'),
];

foreach ($envVars as $key => $value) {
    if ($value === false || $value === null) {
        echo "❌ $key: 未設定\n";
    } else {
        echo "✅ $key: " . (strlen($value) > 20 ? substr($value, 0, 20) . '...' : $value) . "\n";
    }
}

echo "\n";

// 檢查 2：檔案存在性
echo "📁 檢查 2：檔案存在性\n";
$files = [
    '.env' => __DIR__ . '/.env',
    'env.example' => __DIR__ . '/config/env.example',
    'JWTManager.php' => __DIR__ . '/utils/JWTManager.php',
    'database.php' => __DIR__ . '/config/database.php',
];

foreach ($files as $name => $path) {
    if (file_exists($path)) {
        echo "✅ $name: 存在\n";
    } else {
        echo "❌ $name: 不存在\n";
    }
}

echo "\n";

// 檢查 3：JWT 功能測試
echo "🔐 檢查 3：JWT 功能測試\n";
if (class_exists('JWTManager')) {
    echo "✅ JWTManager 類別已載入\n";
    
    try {
        // 測試 JWT 生成
        $payload = ['user_id' => 1, 'email' => 'test@example.com'];
        $token = JWTManager::generateToken($payload);
        
        if ($token && strlen($token) > 50) {
            echo "✅ JWT Token 生成成功，長度: " . strlen($token) . "\n";
            
            // 測試 JWT 驗證
            $decoded = JWTManager::validateToken($token);
            if ($decoded) {
                echo "✅ JWT Token 驗證成功\n";
            } else {
                echo "❌ JWT Token 驗證失敗\n";
            }
        } else {
            echo "❌ JWT Token 生成失敗或格式錯誤\n";
        }
    } catch (Exception $e) {
        echo "❌ JWT 測試失敗: " . $e->getMessage() . "\n";
    }
} else {
    echo "❌ JWTManager 類別未載入\n";
}

echo "\n";

// 檢查 4：資料庫連線測試
echo "🗄️ 檢查 4：資料庫連線測試\n";
try {
    require_once __DIR__ . '/config/database.php';
    
    if (class_exists('Database')) {
        echo "✅ Database 類別已載入\n";
        
        $db = Database::getInstance();
        if ($db) {
            echo "✅ 資料庫連線成功\n";
        } else {
            echo "❌ 資料庫連線失敗\n";
        }
    } else {
        echo "❌ Database 類別未載入\n";
    }
} catch (Exception $e) {
    echo "❌ 資料庫測試失敗: " . $e->getMessage() . "\n";
}

echo "\n";

// 檢查 5：建議解決方案
echo "💡 檢查 5：建議解決方案\n";
if (!getenv('JWT_SECRET')) {
    echo "⚠️  問題：JWT_SECRET 未設定\n";
    echo "🔧 解決方案：\n";
    echo "   1. 複製 backend/config/env.example 到 backend/.env\n";
    echo "   2. 設定 JWT_SECRET 為安全的隨機字串\n";
    echo "   3. 重新啟動 Socket 伺服器\n\n";
}

if (!file_exists(__DIR__ . '/.env')) {
    echo "⚠️  問題：缺少 .env 檔案\n";
    echo "🔧 解決方案：\n";
    echo "   1. 創建 backend/.env 檔案\n";
    echo "   2. 參考 backend/config/env.example 設定\n";
    echo "   3. 確保 JWT_SECRET 已設定\n\n";
}

echo "🎯 檢查完成！\n";
?>

