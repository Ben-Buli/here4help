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
    
    $fullName = trim($input['full_name'] ?? '');
    $nickname = trim($input['nickname'] ?? '');
    $email = trim($input['email'] ?? '');
    $phone = trim($input['phone'] ?? '');
    $referralCode = trim($input['referral_code'] ?? '');
    $school = $input['school'] ?? null;
    $primaryLanguage = $input['primary_language'] ?? 'English';
    $avatarUrl = $input['avatar_url'] ?? null;
    $provider = $input['provider'] ?? '';
    $providerUserId = $input['provider_user_id'] ?? '';
    
    // 驗證輸入
    if (empty($fullName)) {
        throw new Exception('Full name is required');
    }
    
    if (empty($email)) {
        throw new Exception('Email is required');
    }
    
    if (empty($provider) || empty($providerUserId)) {
        throw new Exception('Provider information is required');
    }
    
    error_log("OAuth Signup - 開始處理用戶註冊: $email, Provider: $provider");
    
    // 建立資料庫連線
    $db = Database::getInstance();
    
    // 檢查 email 是否已存在於 users 表
    $stmt = $db->query(
        "SELECT * FROM users WHERE email = ?",
        [$email]
    );
    
    $existingUser = $stmt->fetch();
    
    if ($existingUser) {
        error_log("OAuth Signup - Email 已存在，用戶 ID: {$existingUser['id']}");
        
        // Email 已存在，檢查是否已有對應的 user_identity
        $stmt = $db->query(
            "SELECT * FROM user_identities WHERE user_id = ? AND provider = ?",
            [$existingUser['id'], $provider]
        );
        
        $existingIdentity = $stmt->fetch();
        
        if ($existingIdentity) {
            // 已有對應的 user_identity，直接登入
            error_log("OAuth Signup - 已有對應的 user_identity，直接登入");
            
            $user = $existingUser;
            $isNewUser = false;
        } else {
            // 沒有對應的 user_identity，建立新的綁定
            error_log("OAuth Signup - 建立新的 user_identity 綁定");
            
            $db->query(
                "INSERT INTO user_identities (
                    user_id, provider, provider_user_id, email, name, avatar_url, 
                    raw_profile, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW())",
                [
                    $existingUser['id'], 
                    $provider, 
                    $providerUserId, 
                    $email, 
                    $fullName, 
                    $avatarUrl,
                    json_encode($input) // 儲存原始資料
                ]
            );
            
            $user = $existingUser;
            $isNewUser = false;
        }
    } else {
        error_log("OAuth Signup - 完全新用戶，建立新帳號");
        
        // 完全新用戶，建立 users 記錄
        $db->query(
            "INSERT INTO users (
                name, nickname, email, phone, avatar_url, status, 
                school, primary_language, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, 'active', ?, ?, NOW(), NOW())",
            [$fullName, $nickname, $email, $phone, $avatarUrl, $school, $primaryLanguage]
        );
        
        $userId = $db->lastInsertId();
        error_log("OAuth Signup - 新用戶建立成功，用戶 ID: $userId");
        
        // 建立 user_identity 記錄
        $db->query(
            "INSERT INTO user_identities (
                user_id, provider, provider_user_id, email, name, avatar_url, 
                raw_profile, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW())",
            [
                $userId, 
                $provider, 
                $providerUserId, 
                $email, 
                $fullName, 
                $avatarUrl,
                json_encode($input) // 儲存原始資料
            ]
        );
        
        // 處理推薦碼（如果有的話）
        if (!empty($referralCode)) {
            error_log("OAuth Signup - 處理推薦碼: $referralCode");
            
            // 這裡可以實作推薦碼邏輯
            // 暫時只記錄到日誌
        }
        
        // 重新查詢用戶資料
        $stmt = $db->query("SELECT * FROM users WHERE id = ?", [$userId]);
        $user = $stmt->fetch();
        $isNewUser = true;
        
        error_log("OAuth Signup - 新用戶和 user_identity 建立完成");
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
        error_log("JWT token generated successfully for user: " . $user['id']);
    } catch (Exception $e) {
        error_log("JWT token generation failed: " . $e->getMessage());
        throw new Exception('Token generation failed: ' . $e->getMessage());
    }
    
    // 準備回應資料
    $userData = [
        'id' => $user['id'],
        'name' => $user['name'] ?? '',
        'nickname' => $user['nickname'] ?? '',
        'email' => $user['email'] ?? '',
        'phone' => $user['phone'] ?? '',
        'avatar_url' => $user['avatar_url'] ?? '',
        'points' => (int)($user['points'] ?? 0),
        'status' => $user['status'],
        'school' => $user['school'] ?? '',
        'primary_language' => $user['primary_language'] ?? 'English',
        'provider' => $provider,
        'created_at' => $user['created_at'],
        'updated_at' => $user['updated_at'],
        'referral_code' => $user['referral_code'] ?? '',
        'permission' => (int)($user['permission'] ?? 0),
        'is_new_user' => $isNewUser,
        'provider_user_id' => $providerUserId
    ];
    
    error_log("OAuth Signup - 註冊成功，用戶 ID: {$user['id']}, 新用戶: " . ($isNewUser ? '是' : '否'));
    
    echo json_encode([
        'success' => true,
        'message' => 'OAuth signup successful',
        'data' => [
            'token' => $token,
            'user' => $userData
        ]
    ]);
    
} catch (Exception $e) {
    error_log("OAuth Signup Error: " . $e->getMessage());
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
