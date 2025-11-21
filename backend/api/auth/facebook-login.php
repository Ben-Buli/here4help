<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

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
    
    $facebookId = $input['facebook_id'] ?? '';
    $email = trim($input['email'] ?? '');
    $name = trim($input['name'] ?? '');
    $avatarUrl = $input['avatar_url'] ?? '';
    $accessToken = $input['access_token'] ?? '';
    
    // 驗證輸入
    if (empty($facebookId) || empty($name)) {
        throw new Exception('Facebook ID and name are required');
    }
    
    error_log("Facebook Login - 開始處理用戶: $email, Facebook ID: $facebookId");
    
    // 建立資料庫連線
    $db = Database::getInstance();
    
    // 第一步：檢查是否已存在對應的 user_identity
    error_log("Facebook Login - 檢查現有 user_identity...");
    $stmt = $db->query(
        "SELECT ui.*, u.* FROM user_identities ui 
         INNER JOIN users u ON ui.user_id = u.id 
         WHERE ui.provider = 'facebook' AND ui.provider_user_id = ?",
        [$facebookId]
    );
    
    $existingIdentity = $stmt->fetch();

    $user = null;
    $isNewUser = false;

    if ($existingIdentity) {
        error_log("Facebook Login - 找到現有用戶，用戶 ID: {$existingIdentity['user_id']}");

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
        error_log("Facebook Login - 現有用戶登入成功");
    } else {
        error_log("Facebook Login - 無現有身份，檢查 email 是否已存在...");

        if (!empty($email)) {
            $stmt = $db->query(
                "SELECT * FROM users WHERE email = ?",
                [$email]
            );

            $existingUser = $stmt->fetch();

            if ($existingUser) {
                error_log("Facebook Login - Email 已存在，綁定至用戶 ID: {$existingUser['id']}");

                $db->query(
                    "INSERT INTO user_identities (
                        user_id, provider, provider_user_id, email, name, avatar_url, 
                        access_token, raw_profile, created_at, updated_at
                    ) VALUES (?, 'facebook', ?, ?, ?, ?, ?, ?, NOW(), NOW())",
                    [
                        $existingUser['id'],
                        $facebookId,
                        $email,
                        $name,
                        $avatarUrl,
                        $accessToken,
                        json_encode($input, JSON_UNESCAPED_UNICODE)
                    ]
                );

                $user = $existingUser;
                error_log("Facebook Login - 成功綁定 Facebook 帳號到現有用戶");
            }
        }

        if ($user === null) {
            error_log("Facebook Login - 建立 OAuth 暫存資料供新用戶註冊");

            $tempToken = bin2hex(openssl_random_pseudo_bytes(24));
            $expiresAt = date('Y-m-d H:i:s', time() + 3600);

            $db->query(
                "INSERT INTO oauth_temp_users (provider, provider_user_id, email, name, avatar_url, raw_data, token, expired_at, created_at)
                 VALUES ('facebook', ?, ?, ?, ?, ?, ?, ?, NOW())
                 ON DUPLICATE KEY UPDATE
                   email = VALUES(email),
                   name = VALUES(name),
                   avatar_url = VALUES(avatar_url),
                   raw_data = VALUES(raw_data),
                   token = VALUES(token),
                   expired_at = VALUES(expired_at)",
                [
                    $facebookId,
                    $email ?: null,
                    $name ?: null,
                    $avatarUrl ?: null,
                    json_encode([
                        'raw_input' => $input,
                        'provider' => 'facebook',
                    ], JSON_UNESCAPED_UNICODE),
                    $tempToken,
                    $expiresAt
                ]
            );

            $responseData = [
                'is_new_user' => true,
                'provider' => 'facebook',
                'provider_user_id' => $facebookId,
                'email' => $email,
                'name' => $name,
                'avatar_url' => $avatarUrl,
                'temp_token' => $tempToken,
                'temp_expires_at' => $expiresAt,
            ];

            Response::success($responseData, 'Signup required');
            return;
        }
    }
    
    // 生成 Access/Refresh Token
    $resolvedUserId = isset($user['id']) ? (int)$user['id'] : (int)($user['user_id'] ?? 0);
    $payload = [
        'user_id' => $resolvedUserId,
        'email' => $user['email'] ?? '',
        'name' => $user['name'] ?? $name,
    ];

    try {
        $tokenPair = JWTManager::generateTokenPair($payload);
        $token = $tokenPair['access_token'];
    } catch (Exception $e) {
        error_log("JWT token generation failed: " . $e->getMessage());
        throw new Exception('Token generation failed: ' . $e->getMessage());
    }

    // 準備回應資料
    $userData = [
        'id' => $resolvedUserId,
        'name' => $user['name'] ?? $name,
        'email' => $user['email'] ?? $email,
        'phone' => $user['phone'] ?? '',
        'nickname' => $user['nickname'] ?? ($user['name'] ?? $name),
        'avatar_url' => $user['avatar_url'] ?? $avatarUrl,
        'points' => (int)($user['points'] ?? 0),
        'status' => $user['status'] ?? 'active',
        'provider' => 'facebook',
        'created_at' => $user['created_at'] ?? '',
        'updated_at' => $user['updated_at'] ?? '',
        'referral_code' => $user['referral_code'] ?? '',
        'primary_language' => $user['primary_language'] ?? 'English',
        'permission' => (int)($user['permission'] ?? 0),
        'is_new_user' => false,
        'provider_user_id' => $facebookId,
        'facebook_id' => $facebookId,
        'token' => $token,
        'access_token' => $token,
        'refresh_token' => $tokenPair['refresh_token'],
        'token_type' => $tokenPair['token_type'],
        'expires_in' => $tokenPair['expires_in'],
        'refresh_expires_in' => $tokenPair['refresh_expires_in'],
    ];

    error_log("Facebook Login - 登入成功，用戶 ID: {$resolvedUserId}, 新用戶: 否");

    Response::success($userData, 'Facebook login successful');
    return;
    
} catch (Exception $e) {
    error_log("Facebook Login Error: " . $e->getMessage());
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
