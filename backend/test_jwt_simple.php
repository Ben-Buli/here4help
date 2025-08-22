<?php
/**
 * 簡單的 JWT 測試腳本
 */

echo "🧪 開始測試 JWT 功能...\n\n";

// 引入 JWT 組件
require_once __DIR__ . '/utils/JWTManager.php';

try {
    echo "1️⃣ 測試 JWT Token 生成...\n";
    
    $payload = [
        'user_id' => 123,
        'email' => 'test@example.com',
        'name' => 'Test User'
    ];
    
    $token = JWTManager::generateToken($payload);
    echo "✅ Token 生成成功: " . substr($token, 0, 50) . "...\n\n";
    
    echo "2️⃣ 測試 JWT Token 驗證...\n";
    $payload = JWTManager::validateToken($token);
    
    if ($payload) {
        echo "✅ Token 驗證成功\n";
        echo "   - 用戶 ID: " . $payload['user_id'] . "\n";
        echo "   - 郵箱: " . $payload['email'] . "\n";
        echo "   - 名稱: " . $payload['name'] . "\n";
    } else {
        echo "❌ Token 驗證失敗\n";
    }
    
    echo "\n🎉 JWT 測試完成！\n";
    
} catch (Exception $e) {
    echo "❌ 測試失敗: " . $e->getMessage() . "\n";
    echo "📋 錯誤詳情: " . $e->getTraceAsString() . "\n";
}
?>

