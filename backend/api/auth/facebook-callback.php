<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

// 引入必要的檔案
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';

// 載入環境配置
require_once __DIR__ . '/../../config/env_loader.php';

// 啟動 session 管理
session_start();

try {
    // 檢查是否為 GET 請求（OAuth 回調通常是 GET）
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        throw new Exception('Invalid request method');
    }
    
    // 獲取回調參數
    $code = $_GET['code'] ?? '';
    $state = $_GET['state'] ?? '';
    $error = $_GET['error'] ?? '';
    
    error_log("Facebook OAuth Callback - 開始處理回調");
    error_log("Code: $code");
    error_log("State: $state");
    
    // 檢查是否有錯誤
    if (!empty($error)) {
        throw new Exception("OAuth error: $error");
    }
    
    // 驗證必要參數
    if (empty($code)) {
        throw new Exception('Authorization code is required');
    }
    
    if (empty($state)) {
        throw new Exception('State parameter is required');
    }
    
    // 驗證 state 參數（防止 CSRF 攻擊）
    if (!preg_match('/^web_facebook_\d+$/', $state)) {
        throw new Exception('Invalid state parameter');
    }
    
    // 從環境配置獲取 Facebook OAuth 設定
    $appId = EnvLoader::get('FACEBOOK_APP_ID', '');
    $appSecret = EnvLoader::get('FACEBOOK_APP_SECRET', '');
    $redirectUri = EnvLoader::get('FACEBOOK_REDIRECT_URI', 'http://localhost:8888/here4help/backend/api/auth/facebook-callback.php');
    
    if (empty($appId) || empty($appSecret)) {
        throw new Exception('Facebook OAuth configuration is incomplete');
    }
    
    error_log("Facebook OAuth Callback - 配置驗證通過");
    
    // 第一步：使用授權碼交換 access token
    error_log("Facebook OAuth Callback - 開始交換 access token");
    
    $tokenUrl = 'https://graph.facebook.com/v18.0/oauth/access_token';
    $tokenData = [
        'client_id' => $appId,
        'client_secret' => $appSecret,
        'code' => $code,
        'redirect_uri' => $redirectUri,
    ];
    
    // 使用 file_get_contents 替代 cURL
    $context = stream_context_create([
        'http' => [
            'method' => 'POST',
            'header' => 'Content-Type: application/x-www-form-urlencoded',
            'content' => http_build_query($tokenData)
        ]
    ]);
    
    $tokenResponse = file_get_contents($tokenUrl, false, $context);
    if ($tokenResponse === false) {
        throw new Exception('Failed to exchange authorization code for access token');
    }
    
    $tokenResult = json_decode($tokenResponse, true);
    if (!$tokenResult || !isset($tokenResult['access_token'])) {
        throw new Exception('Invalid token response from Facebook');
    }
    
    $accessToken = $tokenResult['access_token'];
    
    error_log("Facebook OAuth Callback - Access token 獲取成功");
    
    // 第二步：使用 access token 獲取用戶資料
    error_log("Facebook OAuth Callback - 開始獲取用戶資料");
    
    $userInfoUrl = 'https://graph.facebook.com/me?fields=id,name,email,picture&access_token=' . urlencode($accessToken);
    $userInfoResponse = file_get_contents($userInfoUrl);
    if ($userInfoResponse === false) {
        throw new Exception('Failed to fetch user information from Facebook');
    }
    
    $userInfo = json_decode($userInfoResponse, true);
    if (!$userInfo || !isset($userInfo['id'])) {
        throw new Exception('Invalid user information from Facebook');
    }
    
    error_log("Facebook OAuth Callback - 用戶資料獲取成功");
    
    // 第三步：處理用戶登入邏輯（類似 facebook-login.php）
    $facebookId = $userInfo['id'];
    $email = trim($userInfo['email'] ?? '');
    $name = trim($userInfo['name'] ?? '');
    $avatarUrl = $userInfo['picture']['data']['url'] ?? '';
    
    // 建立資料庫連線
    $db = Database::getInstance();
    
    // 檢查是否已存在對應的 user_identity
    $stmt = $db->query(
        "SELECT ui.*, u.* FROM user_identities ui 
         INNER JOIN users u ON ui.user_id = u.id 
         WHERE ui.provider = 'facebook' AND ui.provider_user_id = ?",
        [$facebookId]
    );
    
    $existingIdentity = $stmt->fetch();
    $isNewUser = false;
    
    if ($existingIdentity) {
        // 現有用戶，更新最後登入時間
        $db->query(
            "UPDATE users SET updated_at = NOW() WHERE id = ?",
            [$existingIdentity['user_id']]
        );
        
        $user = $existingIdentity;
        error_log("Facebook OAuth Callback - 現有用戶登入成功");
    } else {
        // 新用戶，需要導向註冊頁面
        $isNewUser = true;
        
        // 建立臨時用戶記錄
        $oauthToken = bin2hex(random_bytes(32));
        $expiredAt = date('Y-m-d H:i:s', time() + 3600); // 1小時後過期
        
        $db->query(
            "INSERT INTO oauth_temp_users (
                token, provider, provider_user_id, email, name, avatar_url, 
                raw_data, expired_at, created_at
            ) VALUES (?, 'facebook', ?, ?, ?, ?, ?, ?, NOW())",
            [
                $oauthToken, $facebookId, $email, $name, $avatarUrl,
                json_encode($userInfo), $expiredAt
            ]
        );
        
        error_log("Facebook OAuth Callback - 新用戶，建立臨時記錄");
    }
    
    // 準備重定向 URL
    $frontendUrl = EnvLoader::get('FRONTEND_URL', 'http://localhost:3000');
    
    if ($isNewUser) {
        // 新用戶：重定向到註冊頁面
        $redirectUrl = $frontendUrl . '/auth/callback?success=true&provider=facebook&oauth_token=' . urlencode($oauthToken);
    } else {
        // 現有用戶：生成 JWT 並重定向到主頁
        $payload = [
            'user_id' => $user['id'],
            'email' => $user['email'] ?? '',
            'name' => $user['name'],
            'iat' => time(),
            'exp' => time() + (60 * 60 * 24 * 7) // 7 天過期
        ];
        
        $token = JWTManager::generateToken($payload);
        
        $userData = [
            'id' => $user['id'],
            'name' => $user['name'] ?? '',
            'email' => $user['email'] ?? '',
            'provider' => 'facebook',
        ];
        
        $redirectUrl = $frontendUrl . '/auth/callback?success=true&provider=facebook&token=' . urlencode($token) . '&user_data=' . urlencode(json_encode($userData));
    }
    
    error_log("Facebook OAuth Callback - 重定向到: $redirectUrl");
    
    // 重定向到前端
    header('Location: ' . $redirectUrl);
    exit;
    
} catch (Exception $e) {
    error_log("Facebook OAuth Callback Error: " . $e->getMessage());
    
    // 重定向到錯誤頁面
    $frontendUrl = EnvLoader::get('FRONTEND_URL', 'http://localhost:3000');
    $errorUrl = $frontendUrl . '/auth/callback?success=false&provider=facebook&error=' . urlencode($e->getMessage());
    
    header('Location: ' . $errorUrl);
    exit;
}
?>
