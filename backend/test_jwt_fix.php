<?php
/**
 * JWT 功能測試腳本
 * 用於驗證 JWT 生成和驗證是否正常
 */

// 載入測試環境配置
require_once 'config/env_test.php';

// 載入 JWT 管理器
require_once 'utils/JWTManager.php';

echo "🧪 開始 JWT 功能測試...\n\n";

try {
    // 測試 1：生成 JWT Token
    echo "📝 測試 1：生成 JWT Token\n";
    $payload = [
        'user_id' => 123,
        'email' => 'test@example.com',
        'name' => 'Test User'
    ];
    
    $token = JWTManager::generateToken($payload);
    echo "✅ Token 生成成功\n";
    echo "🔑 Token: $token\n";
    echo "📏 Token 長度: " . strlen($token) . "\n\n";
    
    // 測試 2：驗證 JWT Token
    echo "🔍 測試 2：驗證 JWT Token\n";
    $decoded = JWTManager::validateToken($token);
    
    if ($decoded) {
        echo "✅ Token 驗證成功\n";
        echo "👤 用戶 ID: " . $decoded['user_id'] . "\n";
        echo "📧 Email: " . $decoded['email'] . "\n";
        echo "👤 姓名: " . $decoded['name'] . "\n";
        echo "⏰ 簽發時間: " . date('Y-m-d H:i:s', $decoded['iat']) . "\n";
        echo "⏰ 過期時間: " . date('Y-m-d H:i:s', $decoded['exp']) . "\n\n";
    } else {
        echo "❌ Token 驗證失敗\n\n";
    }
    
    // 測試 3：獲取 Token 資訊
    echo "📊 測試 3：獲取 Token 資訊\n";
    $tokenInfo = JWTManager::getTokenInfo($token);
    
    if (isset($tokenInfo['error'])) {
        echo "❌ 獲取 Token 資訊失敗: " . $tokenInfo['error'] . "\n\n";
    } else {
        echo "✅ Token 資訊獲取成功\n";
        echo "📋 Header: " . json_encode($tokenInfo['header']) . "\n";
        echo "📋 Payload: " . json_encode($tokenInfo['payload']) . "\n";
        echo "🔐 簽名長度: " . $tokenInfo['signature_length'] . "\n";
        echo "✅ 是否有效: " . ($tokenInfo['is_valid'] ? '是' : '否') . "\n";
        echo "⏰ 剩餘時間: " . $tokenInfo['expires_in'] . " 秒\n";
        echo "⚠️ 是否即將過期: " . ($tokenInfo['is_expiring_soon'] ? '是' : '否') . "\n\n";
    }
    
    // 測試 4：測試無效 Token
    echo "🚫 測試 4：測試無效 Token\n";
    $invalidToken = "invalid.token.here";
    $invalidDecoded = JWTManager::validateToken($invalidToken);
    
    if ($invalidDecoded === false) {
        echo "✅ 無效 Token 正確被拒絕\n\n";
    } else {
        echo "❌ 無效 Token 不應該被接受\n\n";
    }
    
    echo "🎉 所有測試完成！\n";
    
} catch (Exception $e) {
    echo "❌ 測試過程中發生錯誤: " . $e->getMessage() . "\n";
    echo "📍 錯誤位置: " . $e->getFile() . ":" . $e->getLine() . "\n";
}
?>

