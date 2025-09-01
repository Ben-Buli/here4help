<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

// 只允許 POST 請求
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

// 引入資料庫配置
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';

try {
    // 獲取 POST 資料
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }
    
    $googleId = $input['google_id'] ?? '';
    $email = trim($input['email'] ?? '');
    $name = trim($input['name'] ?? '');
    $avatarUrl = $input['avatar_url'] ?? '';
    $accessToken = $input['access_token'] ?? '';
    $idToken = $input['id_token'] ?? '';
    
    // 驗證輸入
    if (empty($googleId) || empty($name)) {
        throw new Exception('Google ID and name are required');
    }
    
    error_log("Google Login - 開始處理用戶: $email, Google ID: $googleId");
    
    // 建立資料庫連線
    $db = Database::getInstance();
    
    // 第一步：檢查是否已存在對應的 user_identity
    error_log("Google Login - 檢查現有 user_identity...");
    $stmt = $db->query(
        "SELECT ui.*, u.* FROM user_identities ui 
         INNER JOIN users u ON ui.user_id = u.id 
         WHERE ui.provider = 'google' AND ui.provider_user_id = ?",
        [$googleId]
    );
    
    $existingIdentity = $stmt->fetch();
    
    if ($existingIdentity) {
        error_log("Google Login - 找到現有用戶，用戶 ID: {$existingIdentity['user_id']}");
        
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
        
        // 生成 JWT Token
        $payload = [
            'user_id' => $user['user_id'],
            'email' => $user['email'] ?? '',
            'name' => $user['name'],
            'iat' => time(),
            'exp' => time() + (60 * 60 * 24 * 7) // 7 天過期
        ];
        
        $token = JWTManager::generateToken($payload);
        
        // 準備回應資料
        $userData = [
            'id' => $user['user_id'],
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
            'is_new_user' => false,
            'provider_user_id' => $googleId
        ];
        
        error_log("Google Login - 現有用戶登入成功");
        
        echo json_encode([
            'success' => true,
            'message' => 'Google login successful',
            'data' => [
                'token' => $token,
                'user' => $userData
            ]
        ]);
        
    } else {
        error_log("Google Login - 新用戶，檢查 email 是否已存在...");
        
        // 檢查 email 是否已存在於 users 表
        if (!empty($email)) {
            $stmt = $db->query(
                "SELECT * FROM users WHERE email = ?",
                [$email]
            );
            
            $existingUser = $stmt->fetch();
            
            if ($existingUser) {
                // 與規劃一致：不在此自動綁定，回覆需綁定提示
                error_log("Google Login - Email 已存在，請綁定現有帳號，用戶 ID: {$existingUser['id']}");
                echo json_encode([
                    'success' => false,
                    'code' => 'ACCOUNT_EXISTS_NEED_BIND',
                    'message' => 'Account exists, please bind',
                    'provider' => 'google',
                    'provider_user_id' => $googleId,
                    'email' => $email
                ]);
            } else {
                // 完全新用戶 → 寫入 oauth_temp_users 並回傳 oauth_token
                error_log("Google Login - 完全新用戶，建立 oauth_temp_users 暫存並回傳 token");
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
                        json_encode($input),
                        $tempToken,
                        $expiresAt
                    ]
                );
                echo json_encode([
                    'success' => true,
                    'is_new_user' => true,
                    'message' => 'New user, please complete registration',
                    'oauth_token' => $tempToken,
                    'temp_identity' => [
                        'provider' => 'google',
                        'provider_user_id' => $googleId,
                        'email' => $email,
                        'name' => $name,
                        'avatar_url' => $avatarUrl
                    ]
                ]);
            }
        } else {
            // 無 email 也視為新用戶 → 寫入 oauth_temp_users 並回傳 oauth_token
            error_log("Google Login - 無 email 新用戶，建立 oauth_temp_users 暫存並回傳 token");
            $tempToken = bin2hex(openssl_random_pseudo_bytes(24));
            $expiresAt = date('Y-m-d H:i:s', time() + 3600);
            $db->query(
                "INSERT INTO oauth_temp_users (provider, provider_user_id, email, name, avatar_url, raw_data, token, expired_at, created_at) 
                 VALUES ('google', ?, ?, ?, ?, ?, ?, ?, NOW())",
                [
                    $googleId,
                    null,
                    $name ?: null,
                    $avatarUrl ?: null,
                    json_encode($input),
                    $tempToken,
                    $expiresAt
                ]
            );
            echo json_encode([
                'success' => true,
                'is_new_user' => true,
                'message' => 'New user, please complete registration',
                'oauth_token' => $tempToken,
                'temp_identity' => [
                    'provider' => 'google',
                    'provider_user_id' => $googleId,
                    'email' => '',
                    'name' => $name,
                    'avatar_url' => $avatarUrl
                ]
            ]);
        }
    }
    
} catch (Exception $e) {
    error_log("Google Login Error: " . $e->getMessage());
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
