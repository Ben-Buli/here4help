<?php
/**
 * Google OAuth 配置測試腳本
 * 用於驗證 Google OAuth 設定是否正確
 */

// 載入環境配置
require_once __DIR__ . '/config/env_loader.php';

echo "🔍 Google OAuth 配置測試\n";
echo "========================\n\n";

// 檢查必要的環境變數
$requiredVars = [
    'GOOGLE_CLIENT_ID',
    'GOOGLE_CLIENT_SECRET',
    'GOOGLE_REDIRECT_URI',
    'FRONTEND_URL'
];

echo "📋 環境變數檢查：\n";
foreach ($requiredVars as $var) {
    $value = EnvLoader::get($var, '');
    $status = !empty($value) ? '✅' : '❌';
    $displayValue = $var === 'GOOGLE_CLIENT_SECRET' ? 
        (empty($value) ? '未設定' : substr($value, 0, 10) . '...') : 
        $value;
    
    echo "  $status $var: $displayValue\n";
}

echo "\n🔧 配置驗證：\n";

// 檢查 Google Client ID 格式
$clientId = EnvLoader::get('GOOGLE_CLIENT_ID', '');
if (preg_match('/^\d+-\w+\.apps\.googleusercontent\.com$/', $clientId)) {
    echo "  ✅ Google Client ID 格式正確\n";
} else {
    echo "  ❌ Google Client ID 格式不正確\n";
}

// 檢查 Google Client Secret 格式
$clientSecret = EnvLoader::get('GOOGLE_CLIENT_SECRET', '');
if (preg_match('/^GOCSPX-/', $clientSecret)) {
    echo "  ✅ Google Client Secret 格式正確\n";
} else {
    echo "  ❌ Google Client Secret 格式不正確或未設定\n";
}

// 檢查重定向 URI
$redirectUri = EnvLoader::get('GOOGLE_REDIRECT_URI', '');
if (filter_var($redirectUri, FILTER_VALIDATE_URL)) {
    echo "  ✅ 重定向 URI 格式正確\n";
} else {
    echo "  ❌ 重定向 URI 格式不正確\n";
}

// 檢查前端 URL
$frontendUrl = EnvLoader::get('FRONTEND_URL', '');
if (filter_var($frontendUrl, FILTER_VALIDATE_URL)) {
    echo "  ✅ 前端 URL 格式正確\n";
} else {
    echo "  ❌ 前端 URL 格式不正確\n";
}

echo "\n📝 建議：\n";

if (empty($clientSecret) || $clientSecret === 'your_google_client_secret_here') {
    echo "  1. 請在 Google Cloud Console 中獲取正確的 Client Secret\n";
    echo "  2. 更新 backend/config/.env 檔案中的 GOOGLE_CLIENT_SECRET\n";
}

if ($frontendUrl === 'http://localhost:8080') {
    echo "  3. 請確認 FRONTEND_URL 是否應該為 http://localhost:3000\n";
}

echo "  4. 確保 Google Cloud Console 中的重定向 URI 設定正確\n";
echo "  5. 確保重定向 URI 在 Google Cloud Console 的授權重定向 URI 清單中\n";

echo "\n🔗 測試 URL：\n";
$testUrl = "https://accounts.google.com/o/oauth2/v2/auth?" . http_build_query([
    'client_id' => $clientId,
    'redirect_uri' => $redirectUri,
    'response_type' => 'code',
    'scope' => 'email profile',
    'state' => 'test_' . time(),
    'access_type' => 'offline',
    'prompt' => 'consent',
]);

echo "  $testUrl\n";

echo "\n⚠️  注意：\n";
echo "  - 請確保 Google Cloud Console 中的 OAuth 2.0 設定正確\n";
echo "  - 重定向 URI 必須完全匹配\n";
echo "  - Client Secret 必須保密且正確\n";
echo "  - 測試時請使用真實的 Google 帳號\n";
?>
