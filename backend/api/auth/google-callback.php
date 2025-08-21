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
    
    // 檢查是否已存在對應的 user_identity
    $stmt = $db->query(
        "SELECT ui.*, u.* FROM user_identities ui 
         INNER JOIN users u ON ui.user_id = u.id 
         WHERE ui.provider = 'google' AND ui.provider_user_id = ?",
        [$googleId]
    );
    
    $existingIdentity = $stmt->fetch();
    
    if ($existingIdentity) {
        error_log("Google OAuth Callback - 找到現有用戶，用戶 ID: {$existingIdentity['user_id']}");
        
        // 現有用戶，更新最後登入時間
        $db->query(
            "UPDATE users SET updated_at = NOW() WHERE id = ?",
            [$existingIdentity['user_id']]
        );
        
        // 更新 user_identity 的 access_token 和最後更新時間
        $db->query(
            "UPDATE user_identities SET 
             access_token = ?, 
             updated_at = NOW() 
             WHERE id = ?",
            [$accessToken, $existingIdentity['id']]
        );
        
        $user = $existingIdentity;
        $isNewUser = false;
        
        error_log("Google OAuth Callback - 現有用戶登入成功");
    } else {
        error_log("Google OAuth Callback - 新用戶，檢查 email 是否已存在...");
        
        // 檢查 email 是否已存在於 users 表
        if (!empty($email)) {
            $stmt = $db->query(
                "SELECT * FROM users WHERE email = ?",
                [$email]
            );
            
            $existingUser = $stmt->fetch();
            
            if ($existingUser) {
                error_log("Google OAuth Callback - Email 已存在，需要綁定到現有帳號，用戶 ID: {$existingUser['id']}");
                
                // Email 已存在，需要綁定到現有帳號
                $db->query(
                    "INSERT INTO user_identities (
                        user_id, provider, provider_user_id, email, name, avatar_url, 
                        access_token, raw_profile, created_at, updated_at
                    ) VALUES (?, 'google', ?, ?, ?, ?, ?, ?, NOW(), NOW())",
                    [
                        $existingUser['id'], 
                        $googleId, 
                        $email, 
                        $name, 
                        $avatarUrl, 
                        $accessToken,
                        json_encode($userInfo) // 儲存原始 Google 資料
                    ]
                );
                
                $user = $existingUser;
                $isNewUser = false;
                
                error_log("Google OAuth Callback - 成功綁定 Google 帳號到現有用戶");
            } else {
                error_log("Google OAuth Callback - 完全新用戶，建立新帳號...");
                
                // 完全新用戶，建立 users 記錄
                $db->query(
                    "INSERT INTO users (
                        name, email, avatar_url, status, created_at, updated_at
                    ) VALUES (?, ?, ?, 'active', NOW(), NOW())",
                    [$name, $email, $avatarUrl]
                );
                
                $userId = $db->lastInsertId();
                error_log("Google OAuth Callback - 新用戶建立成功，用戶 ID: $userId");
                
                // 建立 user_identity 記錄
                $db->query(
                    "INSERT INTO user_identities (
                        user_id, provider, provider_user_id, email, name, avatar_url, 
                        access_token, raw_profile, created_at, updated_at
                    ) VALUES (?, 'google', ?, ?, ?, ?, ?, ?, NOW(), NOW())",
                    [
                        $userId, 
                        $googleId, 
                        $email, 
                        $name, 
                        $avatarUrl, 
                        $accessToken,
                        json_encode($userInfo) // 儲存原始 Google 資料
                    ]
                );
                
                // 重新查詢用戶資料
                $stmt = $db->query("SELECT * FROM users WHERE id = ?", [$userId]);
                $user = $stmt->fetch();
                $isNewUser = true;
                
                error_log("Google OAuth Callback - 新用戶和 user_identity 建立完成");
            }
        } else {
            error_log("Google OAuth Callback - 無 email 的新用戶，建立新帳號...");
            
            // 無 email 的新用戶，建立 users 記錄
            $db->query(
                "INSERT INTO users (
                    name, avatar_url, status, created_at, updated_at
                ) VALUES (?, ?, 'active', NOW(), NOW())",
                [$name, $avatarUrl]
            );
            
            $userId = $db->lastInsertId();
            error_log("Google OAuth Callback - 無 email 新用戶建立成功，用戶 ID: $userId");
            
            // 建立 user_identity 記錄
            $db->query(
                "INSERT INTO user_identities (
                    user_id, provider, provider_user_id, name, avatar_url, 
                    access_token, raw_profile, created_at, updated_at
                ) VALUES (?, 'google', ?, ?, ?, ?, ?, NOW(), NOW())",
                [
                    $userId, 
                    $googleId, 
                    $name, 
                    $avatarUrl, 
                    $accessToken,
                    json_encode($userInfo) // 儲存原始 Google 資料
                ]
            );
            
            // 重新查詢用戶資料
            $stmt = $db->query("SELECT * FROM users WHERE id = ?", [$userId]);
            $user = $stmt->fetch();
            $isNewUser = true;
            
            error_log("Google OAuth Callback - 無 email 新用戶和 user_identity 建立完成");
        }
    }
    
    // 生成 JWT Token
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
    
    error_log("Google OAuth Callback - 登入成功，用戶 ID: {$user['id']}, 新用戶: " . ($isNewUser ? '是' : '否'));
    
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
    if ($isNewUser) {
        // 新用戶：寫入 oauth_temp_users 並產生一次性 token
        $token = bin2hex(random_bytes(24));
        $expiresAt = date('Y-m-d H:i:s', time() + 3600);

        $db->query(
            "INSERT INTO oauth_temp_users (provider, provider_user_id, email, name, avatar_url, raw_data, token, expired_at, created_at)\n             VALUES ('google', ?, ?, ?, ?, ?, ?, ?, NOW())",
            [
                $googleId,
                $email ?: null,
                $name ?: null,
                $avatarUrl ?: null,
                json_encode($userInfo),
                $token,
                $expiresAt
            ]
        );

        // 重定向到註冊頁面（帶 token）
        $redirectUrl = rtrim($frontendUrl, '/') . '/signup?' . http_build_query([
            'token' => $token,
            'provider' => 'google',
            'is_new_user' => 'true'
        ]);

        error_log("Google OAuth Callback - 新用戶建立 temp token 並重定向: $redirectUrl");
    } else {
        // 現有用戶：重定向到主頁
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
