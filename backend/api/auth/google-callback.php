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
    
    error_log("Google OAuth Callback - 開始處理回調");
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
    // 注意：在實際生產環境中，應該將 state 儲存在 session 中進行驗證
    if (!preg_match('/^web_google_\d+$/', $state)) {
        throw new Exception('Invalid state parameter');
    }
    
    // 從環境配置獲取 Google OAuth 設定
    $clientId = EnvLoader::get('GOOGLE_CLIENT_ID', '');
    $clientSecret = EnvLoader::get('GOOGLE_CLIENT_SECRET', '');
    $redirectUri = EnvLoader::get('GOOGLE_REDIRECT_URI', 'http://localhost:8888/here4help/backend/api/auth/google-callback.php');
    
    if (empty($clientId) || empty($clientSecret)) {
        throw new Exception('Google OAuth configuration is missing');
    }
    
    error_log("Google OAuth Callback - 配置驗證通過");
    
    // 第一步：使用授權碼交換 access token
    error_log("Google OAuth Callback - 開始交換 access token");
    
    $tokenUrl = 'https://oauth2.googleapis.com/token';
    $tokenData = [
        'client_id' => $clientId,
        'client_secret' => $clientSecret,
        'code' => $code,
        'grant_type' => 'authorization_code',
        'redirect_uri' => $redirectUri,
    ];
    
    // 使用 file_get_contents 替代 cURL（如果 cURL 不可用）
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
        throw new Exception('Invalid token response from Google');
    }
    
    $accessToken = $tokenResult['access_token'];
    $idToken = $tokenResult['id_token'] ?? '';
    $refreshToken = $tokenResult['refresh_token'] ?? '';
    
    error_log("Google OAuth Callback - Access token 獲取成功");
    
    // 第二步：使用 access token 獲取用戶資料
    error_log("Google OAuth Callback - 開始獲取用戶資料");
    
    $userInfoUrl = 'https://www.googleapis.com/oauth2/v2/userinfo';
    $context = stream_context_create([
        'http' => [
            'method' => 'GET',
            'header' => "Authorization: Bearer $accessToken"
        ]
    ]);
    
    $userInfoResponse = file_get_contents($userInfoUrl, false, $context);
    if ($userInfoResponse === false) {
        throw new Exception('Failed to get user info from Google');
    }
    
    $userInfo = json_decode($userInfoResponse, true);
    if (!$userInfo) {
        throw new Exception('Invalid user info response from Google');
    }
    
    error_log("Google OAuth Callback - 用戶資料獲取成功");
    error_log("用戶資料: " . json_encode($userInfo));
    
    // 提取用戶資訊
    $googleId = $userInfo['id'] ?? '';
    $email = $userInfo['email'] ?? '';
    $name = $userInfo['name'] ?? '';
    $avatarUrl = $userInfo['picture'] ?? '';
    
    if (empty($googleId) || empty($name)) {
        throw new Exception('Required user information is missing');
    }
    
    // 第三步：建立資料庫連線並處理用戶登入
    error_log("Google OAuth Callback - 開始處理用戶登入");
    
    $db = Database::getInstance();
    
    // 情況1：檢查 user_identities 表中是否存在該 email 且 user_id 對應 users.id
    $stmt = $db->query(
        "SELECT ui.*, u.* FROM user_identities ui 
         INNER JOIN users u ON ui.user_id = u.id 
         WHERE ui.provider = 'google' AND ui.email = ?",
        [$email]
    );
    
    $existingIdentityWithValidUser = $stmt->fetch();
    
    if ($existingIdentityWithValidUser) {
        error_log("Google OAuth Callback - 情況1：找到現有用戶，用戶 ID: {$existingIdentityWithValidUser['user_id']}");
        
        // 更新最後登入時間
        $db->query(
            "UPDATE users SET updated_at = NOW() WHERE id = ?",
            [$existingIdentityWithValidUser['user_id']]
        );
        
        // 更新 user_identity 的 access_token
        $db->query(
            "UPDATE user_identities SET 
             access_token = ?, 
             updated_at = NOW() 
             WHERE id = ?",
            [$accessToken, $existingIdentityWithValidUser['id']]
        );
        
        $user = $existingIdentityWithValidUser;
        $isNewUser = false;
        $redirectToSignup = false;
        $existingUserId = null;
        
        error_log("Google OAuth Callback - 情況1：現有用戶登入成功，前往 /home");
    } else {
        // 情況2：檢查 user_identities 表中是否存在該 email 但 user_id 不存在於 users.id
        $stmt = $db->query(
            "SELECT ui.* FROM user_identities ui 
             LEFT JOIN users u ON ui.user_id = u.id 
             WHERE ui.provider = 'google' AND ui.email = ? AND u.id IS NULL",
            [$email]
        );
        
        $existingIdentityWithInvalidUser = $stmt->fetch();
        
        if ($existingIdentityWithInvalidUser) {
            error_log("Google OAuth Callback - 情況2：Email 存在但 user_id 無效，user_id: {$existingIdentityWithInvalidUser['user_id']}");
            
            $user = null;
            $isNewUser = true;
            $redirectToSignup = true;
            $existingUserId = $existingIdentityWithInvalidUser['user_id'];
            
            error_log("Google OAuth Callback - 情況2：前往註冊頁面，傳遞 user_id: $existingUserId");
        } else {
            // 情況3：user_identities.email 不存在且 users 中也不存在
            error_log("Google OAuth Callback - 情況3：完全新用戶，email 不存在於任何表");
            
            $user = null;
            $isNewUser = true;
            $redirectToSignup = true;
            $existingUserId = null;
            
            error_log("Google OAuth Callback - 情況3：前往註冊頁面，不傳遞 user_id");
        }
    }
    
    // 生成 JWT Token（僅在情況1中）
    if ($user !== null) {
        $payload = [
            'user_id' => $user['id'],
            'email' => $user['email'] ?? '',
            'name' => $user['name'],
            'iat' => time(),
            'exp' => time() + (60 * 60 * 24 * 7) // 7 天過期
        ];
        
        try {
            $token = JWTManager::generateToken($payload);
            error_log("Google OAuth Callback - JWT token 生成成功，用戶: " . $user['id']);
        } catch (Exception $e) {
            error_log("Google OAuth Callback - JWT token 生成失敗: " . $e->getMessage());
            throw new Exception('Token generation failed: ' . $e->getMessage());
        }
        
        // 準備用戶資料
        $userData = [
            'id' => $user['id'],
            'name' => $user['name'] ?? '',
            'email' => $user['email'] ?? '',
            'phone' => $user['phone'] ?? '',
            'nickname' => $user['nickname'] ?? '',
            'avatar_url' => $user['avatar_url'] ?? '',
            'points' => (int)($user['points'] ?? 0),
            'status' => $user['status'],
            'provider' => 'google',
            'created_at' => $user['created_at'],
            'updated_at' => $user['updated_at'],
            'referral_code' => $user['referral_code'] ?? '',
            'primary_language' => $user['primary_language'] ?? 'English',
            'permission' => (int)($user['permission'] ?? 0),
            'is_new_user' => $isNewUser,
            'provider_user_id' => $googleId
        ];
    } else {
        // 情況2和3：不需要生成 JWT token
        $token = null;
        $userData = null;
    }
    
    if ($user !== null) {
        error_log("Google OAuth Callback - 登入成功，用戶 ID: {$user['id']}, 新用戶: " . ($isNewUser ? '是' : '否'));
    } else {
        error_log("Google OAuth Callback - 前往註冊頁面，新用戶: " . ($isNewUser ? '是' : '否'));
    }
    
    // 第四步：重定向到前端應用，並傳遞登入結果
    // 根據用戶狀態決定重定向目標
    $allowedOrigins = array_filter(array_map('trim', explode(',', EnvLoader::get('ALLOWED_REDIRECTS', ''))));
    
    // 1) 優先採用 callback 上的 origin 參數（需在發起 OAuth 時附上）
    $origin = $_GET['origin'] ?? '';
    
    // 2) 若無 origin 參數，嘗試使用 HTTP_ORIGIN 或 HTTP_REFERER（僅在與 allowlist 比對通過時採用）
    if (empty($origin)) {
        $candidate = $_SERVER['HTTP_ORIGIN'] ?? ($_SERVER['HTTP_REFERER'] ?? '');
        if (!empty($candidate)) {
            // 只取出 scheme://host[:port]
            $parts = parse_url($candidate);
            if ($parts && isset($parts['scheme'], $parts['host'])) {
                $host = $parts['host'];
                $scheme = $parts['scheme'];
                $port = isset($parts['port']) ? (':' . $parts['port']) : '';
                $origin = $scheme . '://' . $host . $port;
            }
        }
    }
    
    // 3) 驗證是否在允許清單，否則改用環境變數 FRONTEND_URL
    if (!empty($allowedOrigins) && !in_array($origin, $allowedOrigins, true)) {
        $origin = '';
    }
    
    $frontendUrl = $origin ?: EnvLoader::get('FRONTEND_URL', 'http://localhost:3000');
    
    // 根據用戶狀態建立不同的重定向 URL
    if ($redirectToSignup) {
        // 情況2和3：前往註冊頁面
        $tempToken = bin2hex(openssl_random_pseudo_bytes(24));
        $expiresAt = date('Y-m-d H:i:s', time() + 3600);

        $db->query(
            "INSERT INTO oauth_temp_users (provider, provider_user_id, email, name, avatar_url, raw_data, token, expired_at, created_at)
             VALUES ('google', ?, ?, ?, ?, ?, ?, ?, NOW())",
            [
                $googleId,
                $email ?: null,
                $name ?: null,
                $avatarUrl ?: null,
                json_encode($userInfo),
                $tempToken,
                $expiresAt
            ]
        );

        // 重定向到註冊頁面（帶 token 和可選的 existing_user_id）
        $signupParams = [
            'token' => $tempToken,
            'provider' => 'google',
            'is_new_user' => 'true'
        ];
        
        if ($existingUserId !== null) {
            $signupParams['existing_user_id'] = $existingUserId;
        }

        $redirectUrl = rtrim($frontendUrl, '/') . '/signup?' . http_build_query($signupParams);

        error_log("Google OAuth Callback - 前往註冊頁面: $redirectUrl");
        if ($existingUserId !== null) {
            error_log("Google OAuth Callback - 傳遞 existing_user_id: $existingUserId");
        }
    } else {
        // 情況1：現有用戶，重定向到主頁
        $redirectUrl = rtrim($frontendUrl, '/') . '/home?' . http_build_query([
            'token' => $token,
            'user_data' => json_encode($userData),
            'provider' => 'google'
        ]);
        
        error_log("Google OAuth Callback - 現有用戶重定向到主頁: $redirectUrl");
    }
    
    error_log("Google OAuth Callback - 準備重定向到前端: $redirectUrl");
    
    // 重定向到前端應用
    header("Location: $redirectUrl");
    exit;
    
} catch (Exception $e) {
    error_log("Google OAuth Callback Error: " . $e->getMessage());
    
    // 重定向到前端應用，並傳遞錯誤資訊
    $frontendUrl = EnvLoader::get('FRONTEND_URL', 'http://localhost:8080');
    $errorRedirectUrl = $frontendUrl . '/auth/callback?' . http_build_query([
        'success' => 'false',
        'provider' => 'google',
        'error' => $e->getMessage()
    ]);
    
    header("Location: $errorRedirectUrl");
    exit;
}
?>
