<?php
/**
 * 安全功能測試腳本
 * 驗證 CORS、節流、JWT 等安全機制
 */

require_once __DIR__ . '/../config/cors.php';
require_once __DIR__ . '/../utils/RateLimiter.php';
require_once __DIR__ . '/../utils/JWTManager.php';

// 設定測試環境
$_ENV['APP_ENV'] = 'development';

echo "🔒 Here4Help 安全功能測試\n";
echo "========================\n\n";

// 1. 測試 CORS 配置
echo "1. 測試 CORS 配置\n";
echo "----------------\n";

$testOrigins = [
    'http://localhost:3000' => true,
    'http://localhost:8080' => true,
    'https://malicious.com' => false,
    'https://test.ngrok-free.app' => true
];

foreach ($testOrigins as $origin => $expected) {
    $result = CorsConfig::isOriginAllowed($origin);
    $status = $result === $expected ? '✅' : '❌';
    echo "$status $origin: " . ($result ? '允許' : '拒絕') . "\n";
}

echo "\n";

// 2. 測試節流機制
echo "2. 測試節流機制\n";
echo "-------------\n";

// 模擬認證端點測試
$endpoint = '/api/auth/login.php';
echo "測試端點: $endpoint\n";

for ($i = 1; $i <= 7; $i++) {
    $allowed = RateLimiter::checkLimit($endpoint, 'test_user_123');
    $remaining = RateLimiter::getRemainingRequests($endpoint, 'test_user_123');
    $status = $allowed ? '✅' : '❌';
    echo "$status 請求 $i: " . ($allowed ? '允許' : '被限制') . " (剩餘: $remaining)\n";
    
    if (!$allowed) {
        break;
    }
}

echo "\n";

// 3. 測試 JWT Token 對
echo "3. 測試 JWT Token 對\n";
echo "------------------\n";

try {
    // 生成 Token 對
    $payload = [
        'user_id' => 123,
        'email' => 'test@example.com',
        'name' => 'Test User'
    ];
    
    $tokenPair = JWTManager::generateTokenPair($payload);
    echo "✅ Token 對生成成功\n";
    echo "   Access Token 長度: " . strlen($tokenPair['access_token']) . "\n";
    echo "   Refresh Token 長度: " . strlen($tokenPair['refresh_token']) . "\n";
    echo "   過期時間: " . $tokenPair['expires_in'] . " 秒\n";
    
    // 驗證 Access Token
    $accessPayload = JWTManager::validateTokenWithBlacklist($tokenPair['access_token']);
    if ($accessPayload) {
        echo "✅ Access Token 驗證成功\n";
        echo "   用戶 ID: " . $accessPayload['user_id'] . "\n";
        echo "   Token 類型: " . ($accessPayload['type'] ?? 'access') . "\n";
    } else {
        echo "❌ Access Token 驗證失敗\n";
    }
    
    // 測試 Token 刷新
    $newTokenPair = JWTManager::refreshAccessToken($tokenPair['refresh_token']);
    if ($newTokenPair) {
        echo "✅ Token 刷新成功\n";
        echo "   新 Access Token 長度: " . strlen($newTokenPair['access_token']) . "\n";
    } else {
        echo "❌ Token 刷新失敗\n";
    }
    
    // 測試 Token 撤銷
    $revoked = JWTManager::blacklistToken($tokenPair['access_token'], 'test_revocation');
    if ($revoked) {
        echo "✅ Token 撤銷成功\n";
        
        // 驗證撤銷後的 Token
        $revokedPayload = JWTManager::validateTokenWithBlacklist($tokenPair['access_token']);
        if (!$revokedPayload) {
            echo "✅ 撤銷的 Token 驗證正確失敗\n";
        } else {
            echo "❌ 撤銷的 Token 仍然有效（錯誤）\n";
        }
    } else {
        echo "❌ Token 撤銷失敗\n";
    }
    
} catch (Exception $e) {
    echo "❌ JWT 測試發生錯誤: " . $e->getMessage() . "\n";
}

echo "\n";

// 4. 測試清理功能
echo "4. 測試清理功能\n";
echo "-------------\n";

$rateLimitCleaned = RateLimiter::cleanup();
$blacklistCleaned = JWTManager::cleanupBlacklist();

echo "✅ 節流記錄清理: $rateLimitCleaned 個\n";
echo "✅ 黑名單記錄清理: $blacklistCleaned 個\n";

echo "\n";

// 5. 測試統計
echo "5. 測試統計\n";
echo "----------\n";

$storageDir = __DIR__ . '/../storage';
$rateLimitDir = $storageDir . '/rate_limits';
$blacklistDir = $storageDir . '/jwt_blacklist';
$logsDir = $storageDir . '/logs';

$rateLimitFiles = is_dir($rateLimitDir) ? count(glob($rateLimitDir . '/*.txt')) : 0;
$blacklistFiles = is_dir($blacklistDir) ? count(glob($blacklistDir . '/*.json')) : 0;
$logFiles = is_dir($logsDir) ? count(glob($logsDir . '/*.log')) : 0;

echo "📊 儲存統計:\n";
echo "   節流記錄檔案: $rateLimitFiles 個\n";
echo "   黑名單記錄檔案: $blacklistFiles 個\n";
echo "   日誌檔案: $logFiles 個\n";

echo "\n🎉 安全功能測試完成！\n";
?>
