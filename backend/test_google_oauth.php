<?php
// 測試 Google OAuth 配置
require_once __DIR__ . '/config/env_loader.php';

echo "=== Google OAuth 配置測試 ===\n";

// 檢查環境變數
$clientId = EnvLoader::get('GOOGLE_CLIENT_ID', '');
$clientSecret = EnvLoader::get('GOOGLE_CLIENT_SECRET', '');
$redirectUri = EnvLoader::get('GOOGLE_REDIRECT_URI', '');

echo "Client ID: " . ($clientId ? "✅ 已設定" : "❌ 未設定") . "\n";
echo "Client Secret: " . ($clientSecret ? "✅ 已設定" : "❌ 未設定") . "\n";
echo "Redirect URI: $redirectUri\n";

// 檢查 .env 檔案
if (file_exists('.env')) {
    echo "✅ .env 檔案存在\n";
} else {
    echo "❌ .env 檔案不存在\n";
}

// 生成測試的 OAuth URL
$timestamp = time();
$state = "web_google_$timestamp";
$authUrl = "https://accounts.google.com/o/oauth2/v2/auth?" . http_build_query([
    'client_id' => $clientId,
    'redirect_uri' => $redirectUri,
    'response_type' => 'code',
    'scope' => 'email profile',
    'state' => $state,
    'access_type' => 'offline',
    'prompt' => 'consent',
]);

echo "\n=== 測試 OAuth URL ===\n";
echo "State: $state\n";
echo "Auth URL: $authUrl\n";

echo "\n=== 測試步驟 ===\n";
echo "1. 複製上面的 Auth URL\n";
echo "2. 在瀏覽器中打開\n";
echo "3. 完成 Google 登入\n";
echo "4. 檢查重定向的 URL 是否包含有效的 code 參數\n";
echo "5. 如果成功，code 參數會出現在 URL 中\n";
?>
