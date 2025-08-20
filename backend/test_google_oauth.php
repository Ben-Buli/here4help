<?php
/**
 * Google OAuth 回調測試腳本
 * 用於測試 OAuth 回調處理邏輯
 */

// 載入環境配置
require_once __DIR__ . '/config/env_loader.php';

// 載入必要的類別
require_once __DIR__ . '/api/auth/google-callback.php';

echo "🔐 Google OAuth 回調測試腳本\n";
echo "================================\n\n";

// 測試環境配置載入
echo "📋 測試環境配置載入...\n";
try {
    EnvLoader::load();
    echo "✅ 環境配置載入成功\n";
    
    // 顯示關鍵配置
    $googleClientId = EnvLoader::get('GOOGLE_CLIENT_ID', '');
    $googleClientSecret = EnvLoader::get('GOOGLE_CLIENT_SECRET', '');
    $googleRedirectUri = EnvLoader::get('GOOGLE_REDIRECT_URI', '');
    $frontendUrl = EnvLoader::get('FRONTEND_URL', '');
    
    echo "🔑 Google Client ID: " . ($googleClientId ? '已配置' : '未配置') . "\n";
    echo "🔐 Google Client Secret: " . ($googleClientSecret ? '已配置' : '未配置') . "\n";
    echo "🔗 Google Redirect URI: $googleRedirectUri\n";
    echo "🌐 Frontend URL: $frontendUrl\n\n";
    
} catch (Exception $e) {
    echo "❌ 環境配置載入失敗: " . $e->getMessage() . "\n";
    exit(1);
}

// 測試模擬 OAuth 回調參數
echo "🧪 測試模擬 OAuth 回調參數...\n";

// 模擬 Google OAuth 回調參數
$_GET['code'] = 'test_authorization_code_12345';
$_GET['state'] = 'web_google_' . time();
$_GET['error'] = '';

echo "📝 模擬授權碼: " . $_GET['code'] . "\n";
echo "🛡️ 模擬 State: " . $_GET['state'] . "\n";
echo "❌ 模擬錯誤: " . ($_GET['error'] ?: '無') . "\n\n";

// 測試 state 參數驗證
echo "🔒 測試 State 參數驗證...\n";
$state = $_GET['state'];
if (preg_match('/^web_google_\d+$/', $state)) {
    echo "✅ State 參數驗證通過\n";
} else {
    echo "❌ State 參數驗證失敗\n";
}

echo "\n";

// 測試環境變數獲取
echo "🔧 測試環境變數獲取...\n";
$testVars = [
    'GOOGLE_CLIENT_ID',
    'GOOGLE_CLIENT_SECRET', 
    'GOOGLE_REDIRECT_URI',
    'FRONTEND_URL',
    'APP_ENV',
    'DB_HOST'
];

foreach ($testVars as $var) {
    $value = EnvLoader::get($var, '未設定');
    $displayValue = $var === 'GOOGLE_CLIENT_SECRET' ? 
        (strlen($value) > 10 ? substr($value, 0, 10) . '...' : $value) : 
        $value;
    echo "  $var: $displayValue\n";
}

echo "\n";

// 測試資料庫連線（如果可能）
echo "🗄️ 測試資料庫連線...\n";
try {
    require_once __DIR__ . '/config/database.php';
    $db = Database::getInstance();
    echo "✅ 資料庫連線成功\n";
} catch (Exception $e) {
    echo "❌ 資料庫連線失敗: " . $e->getMessage() . "\n";
}

echo "\n";

// 測試 JWT 管理器
echo "🎫 測試 JWT 管理器...\n";
try {
    require_once __DIR__ . '/utils/JWTManager.php';
    $testPayload = [
        'user_id' => 999,
        'email' => 'test@example.com',
        'name' => 'Test User',
        'iat' => time(),
        'exp' => time() + 3600
    ];
    
    $token = JWTManager::generateToken($testPayload);
    echo "✅ JWT Token 生成成功\n";
    echo "   Token 長度: " . strlen($token) . " 字符\n";
    
    // 驗證 token
    $decoded = JWTManager::validateToken($token);
    if ($decoded && $decoded['user_id'] == 999) {
        echo "✅ JWT Token 驗證成功\n";
    } else {
        echo "❌ JWT Token 驗證失敗\n";
    }
    
} catch (Exception $e) {
    echo "❌ JWT 管理器測試失敗: " . $e->getMessage() . "\n";
}

echo "\n";

// 測試 URL 構建
echo "🔗 測試 URL 構建...\n";
$testRedirectUrl = $frontendUrl . '/auth/callback?' . http_build_query([
    'success' => 'true',
    'provider' => 'google',
    'token' => 'test_token_12345',
    'user_data' => json_encode(['id' => 1, 'name' => 'Test User']),
    'is_new_user' => 'false'
]);

echo "   Frontend URL: $frontendUrl\n";
echo "   完整重定向 URL: $testRedirectUrl\n";
echo "✅ URL 構建測試完成\n";

echo "\n";
echo "🎉 Google OAuth 回調測試完成！\n";
echo "================================\n";
echo "📝 注意事項：\n";
echo "1. 確保 .env 檔案已正確配置\n";
echo "2. 檢查 Google Cloud Console 的重定向 URI 設定\n";
echo "3. 測試實際的 OAuth 流程\n";
echo "4. 檢查錯誤日誌以進行除錯\n";
?>
