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
    
    $appleId = $input['apple_id'] ?? '';
    $email = trim($input['email'] ?? '');
    $name = trim($input['name'] ?? '');
    $avatarUrl = $input['avatar_url'] ?? '';
    $identityToken = $input['identity_token'] ?? '';
    $authorizationCode = $input['authorization_code'] ?? '';
    
    // 驗證輸入（只強制要求 apple_id；name 可能在第二次後不再提供）
    if (empty($appleId)) {
        throw new Exception('Apple ID is required');
    }

    // 為缺失的 name 準備安全後備值
    $safeName = $name;
    if (empty($safeName)) {
        if (!empty($email)) {
            $parts = explode('@', $email);
            $safeName = trim($parts[0]);
        }
        if (empty($safeName)) {
            $safeName = 'Apple User';
        }
    }
    
    error_log("Apple Login - 開始處理用戶: $email, Apple ID: $appleId");
    
    // 建立資料庫連線
    $db = Database::getInstance();
    
    // 第一步：檢查是否已存在對應的 user_identity
    error_log("Apple Login - 檢查現有 user_identity...");
    $stmt = $db->query(
        "SELECT ui.*, u.* FROM user_identities ui 
         INNER JOIN users u ON ui.user_id = u.id 
         WHERE ui.provider = 'apple' AND ui.provider_user_id = ?",
        [$appleId]
    );
    
    $existingIdentity = $stmt->fetch();

    $user = null;

    if ($existingIdentity) {
        error_log("Apple Login - 找到現有用戶，用戶 ID: {$existingIdentity['user_id']}");

        $db->query(
            "UPDATE users SET updated_at = NOW() WHERE id = ?",
            [$existingIdentity['user_id']]
        );

        if (!empty($identityToken)) {
            $db->query(
                "UPDATE user_identities SET 
                 access_token = ?, 
                 updated_at = NOW() 
                 WHERE id = ?",
                [$identityToken, $existingIdentity['id']]
            );
        }

        $user = $existingIdentity;
        error_log("Apple Login - 現有用戶登入成功");
    } else {
        error_log("Apple Login - 無現有身份，檢查 email 是否已存在...");

        if (!empty($email)) {
            $stmt = $db->query(
                "SELECT * FROM users WHERE email = ?",
                [$email]
            );

            $existingUser = $stmt->fetch();

            if ($existingUser) {
                error_log("Apple Login - Email 已存在，綁定至用戶 ID: {$existingUser['id']}");

                $db->query(
                    "INSERT INTO user_identities (
                        user_id, provider, provider_user_id, email, name, avatar_url, 
                        access_token, raw_profile, created_at, updated_at
                    ) VALUES (?, 'apple', ?, ?, ?, ?, ?, ?, NOW(), NOW())",
                    [
                        $existingUser['id'],
                        $appleId,
                        $email,
                        $safeName,
                        $avatarUrl,
                        $identityToken,
                        json_encode($input, JSON_UNESCAPED_UNICODE)
                    ]
                );

                $user = $existingUser;
                error_log("Apple Login - 成功綁定 Apple 帳號到現有用戶");
            }
        }

        if ($user === null) {
            error_log("Apple Login - 建立 OAuth 暫存資料供新用戶註冊");

            $tempToken = bin2hex(openssl_random_pseudo_bytes(24));
            $expiresAt = date('Y-m-d H:i:s', time() + 3600);

            $db->query(
                "INSERT INTO oauth_temp_users (provider, provider_user_id, email, name, avatar_url, raw_data, token, expired_at, created_at)
                 VALUES ('apple', ?, ?, ?, ?, ?, ?, ?, NOW())
                 ON DUPLICATE KEY UPDATE
                   email = VALUES(email),
                   name = VALUES(name),
                   avatar_url = VALUES(avatar_url),
                   raw_data = VALUES(raw_data),
                   token = VALUES(token),
                   expired_at = VALUES(expired_at)",
                [
                    $appleId,
                    $email ?: null,
                    $safeName ?: null,
                    $avatarUrl ?: null,
                    json_encode([
                        'raw_input' => $input,
                        'provider' => 'apple',
                    ], JSON_UNESCAPED_UNICODE),
                    $tempToken,
                    $expiresAt
                ]
            );

            $responseData = [
                'is_new_user' => true,
                'provider' => 'apple',
                'provider_user_id' => $appleId,
                'email' => $email,
                'name' => $safeName,
                'avatar_url' => $avatarUrl,
                'temp_token' => $tempToken,
                'temp_expires_at' => $expiresAt,
            ];

            Response::success($responseData, 'Signup required');
            return;
        }
    }
    
    // 生成 JWT Token
    $resolvedUserId = isset($user['id']) ? (int)$user['id'] : (int)($user['user_id'] ?? 0);
    $payload = [
        'user_id' => $resolvedUserId,
        'email' => $user['email'] ?? $email,
        'name' => $user['name'] ?? $safeName,
        'iat' => time(),
        'exp' => time() + (60 * 60 * 24 * 7) // 7 天過期
    ];

    try {
        $token = JWTManager::generateToken($payload);
        error_log("JWT token generated successfully for user: " . $resolvedUserId);
    } catch (Exception $e) {
        error_log("JWT token generation failed: " . $e->getMessage());
        throw new Exception('Token generation failed: ' . $e->getMessage());
    }

    // 準備回應資料
    $userData = [
        'id' => $resolvedUserId,
        'name' => $user['name'] ?? $safeName,
        'email' => $user['email'] ?? $email,
        'phone' => $user['phone'] ?? '',
        'nickname' => $user['nickname'] ?? ($user['name'] ?? $safeName),
        'avatar_url' => $user['avatar_url'] ?? $avatarUrl,
        'points' => (int)($user['points'] ?? 0),
        'status' => $user['status'] ?? 'active',
        'provider' => 'apple',
        'created_at' => $user['created_at'] ?? '',
        'updated_at' => $user['updated_at'] ?? '',
        'referral_code' => $user['referral_code'] ?? '',
        'primary_language' => $user['primary_language'] ?? 'English',
        'permission' => (int)($user['permission'] ?? 0),
        'is_new_user' => false,
        'provider_user_id' => $appleId,
        'apple_id' => $appleId,
        'token' => $token,
    ];

    error_log("Apple Login - 登入成功，用戶 ID: {$resolvedUserId}, 新用戶: 否");

    Response::success($userData, 'Apple login successful');
    return;
    
} catch (Exception $e) {
    error_log("Apple Login Error: " . $e->getMessage());
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
