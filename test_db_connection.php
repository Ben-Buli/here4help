<?php
/**
 * 資料庫連線測試檔案
 * 用於測試 cPanel 部署後的資料庫連線
 */

echo "=== Here4Help 資料庫連線測試 ===\n";
echo "測試時間: " . date('Y-m-d H:i:s') . "\n\n";

// 1. 測試環境變數載入
echo "1. 測試環境變數載入...\n";
try {
    require_once 'backend/config/env_loader.php';
    echo "✅ 環境變數載入器載入成功\n";
} catch (Exception $e) {
    echo "❌ 環境變數載入器載入失敗: " . $e->getMessage() . "\n";
    exit(1);
}

// 2. 檢查環境變數
echo "\n2. 檢查環境變數...\n";
$envVars = [
    'APP_ENVIRONMENT' => EnvLoader::get('APP_ENVIRONMENT'),
    'DB_HOST' => EnvLoader::get('DB_HOST'),
    'DB_PORT' => EnvLoader::get('DB_PORT'),
    'DB_NAME' => EnvLoader::get('DB_NAME'),
    'DB_USERNAME' => EnvLoader::get('DB_USERNAME'),
    'JWT_SECRET' => EnvLoader::get('JWT_SECRET') ? '已設定' : '未設定'
];

foreach ($envVars as $key => $value) {
    echo "   $key: " . ($value ?: '未設定') . "\n";
}

// 3. 測試資料庫連線
echo "\n3. 測試資料庫連線...\n";
try {
    require_once 'backend/config/database.php';
    $db = Database::getInstance();
    echo "✅ 資料庫連線成功！\n";
    
    // 4. 測試基本查詢
    echo "\n4. 測試基本查詢...\n";
    
    // 測試 users 表
    try {
        $userCount = $db->fetch("SELECT COUNT(*) as count FROM users");
        echo "✅ 用戶表查詢成功，用戶數量: " . $userCount['count'] . "\n";
    } catch (Exception $e) {
        echo "⚠️ 用戶表查詢失敗: " . $e->getMessage() . "\n";
    }
    
    // 測試 tasks 表
    try {
        $taskCount = $db->fetch("SELECT COUNT(*) as count FROM tasks");
        echo "✅ 任務表查詢成功，任務數量: " . $taskCount['count'] . "\n";
    } catch (Exception $e) {
        echo "⚠️ 任務表查詢失敗: " . $e->getMessage() . "\n";
    }
    
    // 測試 chat_rooms 表
    try {
        $chatCount = $db->fetch("SELECT COUNT(*) as count FROM chat_rooms");
        echo "✅ 聊天室表查詢成功，聊天室數量: " . $chatCount['count'] . "\n";
    } catch (Exception $e) {
        echo "⚠️ 聊天室表查詢失敗: " . $e->getMessage() . "\n";
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
    
    exit(1);
}

// 5. 測試 JWT 功能
echo "\n5. 測試 JWT 功能...\n";
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

// 6. 測試檔案權限
echo "\n6. 測試檔案權限...\n";
$uploadDirs = [
    'backend/uploads',
    'backend/uploads/avatars',
    'backend/uploads/chat',
    'backend/uploads/student_id_images',
    'backend/uploads/support_chat'
];

foreach ($uploadDirs as $dir) {
    if (is_dir($dir)) {
        $perms = substr(sprintf('%o', fileperms($dir)), -4);
        echo "✅ $dir: 權限 $perms\n";
    } else {
        echo "⚠️ $dir: 目錄不存在\n";
    }
}

echo "\n=== 測試完成 ===\n";
echo "如果所有測試都通過，您的 Backend API 已準備就緒！\n";
?>
