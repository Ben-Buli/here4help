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
require_once '../../config/database.php';
require_once '../../utils/JWTManager.php';
require_once '../../utils/Response.php';

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
    
    // 建立資料庫連線
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
        // 現有用戶，更新最後登入時間
        $db->query(
            "UPDATE users SET updated_at = NOW() WHERE id = ?",
            [$existingIdentity['user_id']]
        );
        
        // 更新 user_identity 的 access_token
        $db->query(
            "UPDATE user_identities SET 
             access_token = ?, 
             updated_at = NOW() 
             WHERE id = ?",
            [$accessToken, $existingIdentity['id']]
        );
        
        $user = $existingIdentity;
        $isNewUser = false;
    } else {
        // 檢查 email 是否已存在於 users 表
        if (!empty($email)) {
            $stmt = $db->query(
                "SELECT * FROM users WHERE email = ?",
                [$email]
            );
            
            $existingUser = $stmt->fetch();
            
            if ($existingUser) {
                // Email 已存在，需要綁定到現有帳號
                // 這裡可以實現帳號綁定流程，或要求用戶先登入現有帳號
                throw new Exception('Email already exists. Please login with your existing account to bind this provider.');
            }
        }
        
        // 新用戶，建立 users 記錄
        $db->query(
            "INSERT INTO users (
                name, email, avatar_url, status, created_at, updated_at
            ) VALUES (?, ?, ?, 'active', NOW(), NOW())",
            [$name, $email, $avatarUrl]
        );
        
        $userId = $db->lastInsertId();
        
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
                json_encode($input) // 儲存原始資料
            ]
        );
        
        // 重新查詢用戶資料
        $stmt = $db->query("SELECT * FROM users WHERE id = ?", [$userId]);
        $user = $stmt->fetch();
        $isNewUser = true;
    }
    
    // 生成 JWT Token
    $payload = [
        'user_id' => $user['id'],
        'email' => $user['email'],
        'name' => $user['name'],
        'iat' => time(),
        'exp' => time() + (60 * 60 * 24 * 7) // 7 天過期
    ];
    
    try {
        $token = JWTManager::generateToken($payload);
        error_log("JWT token generated successfully for user: " . $user['id']);
    } catch (Exception $e) {
        error_log("JWT token generation failed: " . $e->getMessage());
        throw new Exception('Token generation failed: ' . $e->getMessage());
    }
    
    // 準備回應資料
    $userData = [
        'id' => $user['id'],
        'name' => $user['name'] ?? '',
        'email' => $user['email'],
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
    
    echo json_encode([
        'success' => true,
        'message' => 'Google login successful',
        'data' => [
            'token' => $token,
            'user' => $userData
        ]
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
