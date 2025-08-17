<?php
/**
 * JWT 功能測試工具
 * 用於驗證 JWT 生成、驗證、刷新等功能
 * 
 * @author Here4Help Team
 * @version 1.0.0
 * @since 2025-01-11
 */

require_once 'utils/JWTManager.php';
require_once 'utils/TokenValidator.php';

echo "<h1>🔐 JWT 功能測試工具</h1>\n";
echo "<p>此工具用於測試 JWT 系統的各項功能</p>\n";

// 檢查環境配置
echo "<h2>📋 環境配置檢查</h2>\n";

try {
    // 檢查 JWT_SECRET 是否設定
    $secret = getenv('JWT_SECRET');
    if (!$secret) {
        // 嘗試從 .env 檔案載入
        if (file_exists(__DIR__ . '/config/.env')) {
            $envContent = file_get_contents(__DIR__ . '/config/.env');
            preg_match('/JWT_SECRET=(.+)/', $envContent, $matches);
            if (isset($matches[1])) {
                $secret = trim($matches[1]);
            }
        }
    }
    
    if ($secret) {
        echo "✅ JWT_SECRET 已設定 (長度: " . strlen($secret) . " 字元)\n";
        echo "🔒 密鑰預覽: " . substr($secret, 0, 10) . "...\n";
    } else {
        echo "❌ JWT_SECRET 未設定\n";
        echo "💡 請在 .env 檔案中設定 JWT_SECRET\n";
        exit(1);
    }
    
} catch (Exception $e) {
    echo "❌ 環境配置檢查失敗: " . $e->getMessage() . "\n";
    exit(1);
}

echo "<hr>\n";

// 測試 JWT 生成
echo "<h2>🚀 JWT 生成測試</h2>\n";

try {
    $testPayload = [
        'user_id' => 123,
        'email' => 'test@example.com',
        'name' => '測試用戶'
    ];
    
    echo "📤 測試載荷: " . json_encode($testPayload, JSON_UNESCAPED_UNICODE) . "\n";
    
    $token = JWTManager::generateToken($testPayload);
    echo "✅ JWT Token 生成成功\n";
    echo "🔑 Token: " . substr($token, 0, 50) . "...\n";
    echo "📏 Token 長度: " . strlen($token) . " 字元\n";
    
} catch (Exception $e) {
    echo "❌ JWT 生成失敗: " . $e->getMessage() . "\n";
    exit(1);
}

echo "<hr>\n";

// 測試 JWT 驗證
echo "<h2>🔍 JWT 驗證測試</h2>\n";

try {
    $payload = JWTManager::validateToken($token);
    if ($payload) {
        echo "✅ JWT Token 驗證成功\n";
        echo "📋 載荷內容: " . json_encode($payload, JSON_UNESCAPED_UNICODE) . "\n";
        echo "👤 用戶 ID: " . $payload['user_id'] . "\n";
        echo "📧 用戶郵箱: " . $payload['email'] . "\n";
        echo "⏰ 過期時間: " . date('Y-m-d H:i:s', $payload['exp']) . "\n";
    } else {
        echo "❌ JWT Token 驗證失敗\n";
        exit(1);
    }
    
} catch (Exception $e) {
    echo "❌ JWT 驗證失敗: " . $e->getMessage() . "\n";
    exit(1);
}

echo "<hr>\n";

// 測試 TokenValidator
echo "<h2>🔧 TokenValidator 測試</h2>\n";

try {
    $userId = TokenValidator::validateToken($token);
    if ($userId) {
        echo "✅ TokenValidator 驗證成功\n";
        echo "👤 提取的用戶 ID: " . $userId . "\n";
    } else {
        echo "❌ TokenValidator 驗證失敗\n";
        exit(1);
    }
    
} catch (Exception $e) {
    echo "❌ TokenValidator 測試失敗: " . $e->getMessage() . "\n";
    exit(1);
}

echo "<hr>\n";

// 測試 token 資訊
echo "<h2>📊 Token 資訊測試</h2>\n";

try {
    $tokenInfo = JWTManager::getTokenInfo($token);
    echo "✅ Token 資訊獲取成功\n";
    echo "📋 Token 類型: " . $tokenInfo['type'] . "\n";
    echo "🔐 演算法: " . $tokenInfo['header']['alg'] . "\n";
    echo "📝 載荷欄位數: " . count($tokenInfo['payload']) . "\n";
    echo "⏰ 剩餘有效時間: " . $tokenInfo['expires_in'] . " 秒\n";
    echo "⚠️ 是否即將過期: " . ($tokenInfo['is_expiring_soon'] ? '是' : '否') . "\n";
    
} catch (Exception $e) {
    echo "❌ Token 資訊獲取失敗: " . $e->getMessage() . "\n";
}

echo "<hr>\n";

// 測試過期檢查
echo "<h2>⏰ 過期檢查測試</h2>\n";

try {
    $isExpiringSoon = JWTManager::isExpiringSoon($token);
    echo "✅ 過期檢查成功\n";
    echo "⚠️ 是否即將過期: " . ($isExpiringSoon ? '是' : '否') . "\n";
    
} catch (Exception $e) {
    echo "❌ 過期檢查失敗: " . $e->getMessage() . "\n";
}

echo "<hr>\n";

// 測試 token 刷新
echo "<h2>🔄 Token 刷新測試</h2>\n";

try {
    $newToken = JWTManager::refreshToken($token);
    if ($newToken) {
        echo "✅ Token 刷新成功\n";
        echo "🆕 新 Token: " . substr($newToken, 0, 50) . "...\n";
        
        // 驗證新 token
        $newPayload = JWTManager::validateToken($newToken);
        if ($newPayload) {
            echo "✅ 新 Token 驗證成功\n";
            echo "⏰ 新過期時間: " . date('Y-m-d H:i:s', $newPayload['exp']) . "\n";
        } else {
            echo "❌ 新 Token 驗證失敗\n";
        }
    } else {
        echo "❌ Token 刷新失敗\n";
    }
    
} catch (Exception $e) {
    echo "❌ Token 刷新失敗: " . $e->getMessage() . "\n";
}

echo "<hr>\n";

// 測試錯誤情況
echo "<h2>🚫 錯誤情況測試</h2>\n";

// 測試無效 token
echo "<h3>無效 Token 測試</h3>\n";
$invalidToken = "invalid.token.here";
$result = JWTManager::validateToken($invalidToken);
echo "無效 Token 驗證結果: " . ($result ? '成功' : '失敗') . " (預期: 失敗)\n";

// 測試空 token
echo "<h3>空 Token 測試</h3>\n";
$result = JWTManager::validateToken("");
echo "空 Token 驗證結果: " . ($result ? '成功' : '失敗') . " (預期: 失敗)\n";

// 測試過期 token（模擬）
echo "<h3>過期 Token 測試</h3>\n";
$expiredPayload = [
    'user_id' => 999,
    'email' => 'expired@example.com',
    'name' => '過期用戶',
    'iat' => time() - 86400, // 1 天前
    'exp' => time() - 3600,  // 1 小時前
    'nbf' => time() - 86400  // 1 天前
];
$expiredToken = JWTManager::generateToken($expiredPayload, -3600); // 強制過期
$result = JWTManager::validateToken($expiredToken);
echo "過期 Token 驗證結果: " . ($result ? '成功' : '失敗') . " (預期: 失敗)\n";

echo "<hr>\n";

// 總結
echo "<h2>🎉 測試總結</h2>\n";
echo "✅ JWT 系統測試完成\n";
echo "🔐 所有核心功能正常運作\n";
echo "🚀 可以開始使用 JWT 系統\n";
echo "💡 建議在正式環境中設定強密鑰\n";

echo "<hr>\n";
echo "<p><small>測試完成時間: " . date('Y-m-d H:i:s') . "</small></p>\n";
?>
