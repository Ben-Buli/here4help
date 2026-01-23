<?php
require_once __DIR__ . '/bootstrap.php';
// 載入 PHP 8.4 相容性配置

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
require_once __DIR__ . '/../../utils/AccountBlocker.php';

try {
    // 獲取 POST 資料
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }
    
    // 驗證必要欄位
    $requiredFields = ['name', 'email', 'provider', 'provider_user_id'];
    foreach ($requiredFields as $field) {
        if (empty($input[$field])) {
            throw new Exception("Missing required field: $field");
        }
    }
    
    $name = trim($input['name']);
    $email = trim($input['email']);
    $nickname = trim($input['nickname'] ?? '');
    $phone = trim($input['phone'] ?? '');
    $country = trim($input['country'] ?? '');
    $dateOfBirth = $input['date_of_birth'] ?? null;
    $gender = $input['gender'] ?? 'Prefer not to disclose';
    $address = trim($input['address'] ?? '');
    $aboutMe = trim($input['about_me'] ?? '');
    $primaryLanguage = trim($input['primary_language'] ?? 'English');
    $school = trim($input['school'] ?? '');
    $paymentPassword = $input['payment_password'] ?? '';
    $terms = $input['terms'] ?? false;
    
    // 第三方登入相關欄位
    $provider = $input['provider'];
    $providerUserId = $input['provider_user_id'];
    $avatarUrl = $input['avatar_url'] ?? '';
    $accessToken = $input['access_token'] ?? '';
    
    // 驗證條款同意
    if (!$terms) {
        throw new Exception('Terms and conditions must be accepted');
    }
    
    // 驗證 email 格式
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        throw new Exception('Invalid email format');
    }
    
    error_log("Register with Identity - 開始處理用戶註冊: $email, Provider: $provider");
    
    // 建立資料庫連線
    $db = Database::getInstance();
    $pdo = $db->getConnection();
    
    // 檢查 email 是否已存在
    if (AccountBlocker::isEmailBlocked($pdo, $email)) {
        Response::forbidden('ACCOUNT_DELETED_BY_ADMIN');
    }
    $stmt = $db->query("SELECT id FROM users WHERE email = ? AND permission NOT IN (-2, -4) ", [$email]); // 排除管理員刪除用戶、自已刪除的用戶
    $existingUser = $stmt->fetch();
    
    if ($existingUser) {
        throw new Exception('Email already exists');
    }
    
    // 檢查 provider_user_id 是否已存在於 user_identities
    if (AccountBlocker::isIdentityBlocked($pdo, $provider, $providerUserId)) {
        Response::forbidden('ACCOUNT_DELETED_BY_ADMIN');
    }
    $stmt = $db->query(
        "SELECT user_id FROM user_identities WHERE provider = ? AND provider_user_id = ?",
        [$provider, $providerUserId]
    );
    $existingIdentity = $stmt->fetch();
    
    if ($existingIdentity) {
        throw new Exception('Provider account already linked to another user');
    }
    
    // 開始資料庫交易
    $db->beginTransaction();
    
    try {
        // 1. 建立 users 記錄
        $insertUserQuery = "
            INSERT INTO users (
                name, nickname, email, phone, country, date_of_birth, gender, 
                address, about_me, primary_language, school, payment_password, 
                avatar_url, terms_accepted_at, status, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), 'active', NOW(), NOW())
        ";
         
        $db->query($insertUserQuery, [
            $name, $nickname, $email, $phone, $country, $dateOfBirth, $gender,
            $address, $aboutMe, $primaryLanguage, $school, $paymentPassword, $avatarUrl
        ]);
        
        $userId = $db->lastInsertId();
        error_log("Register with Identity - 用戶建立成功，用戶 ID: $userId");
        
        // 2. 建立 user_identities 記錄
        $insertIdentityQuery = "
            INSERT INTO user_identities (
                user_id, provider, provider_user_id, email, name, avatar_url, 
                access_token, raw_profile, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
        ";
        
        $db->query($insertIdentityQuery, [
            $userId, $provider, $providerUserId, $email, $name, $avatarUrl,
            $accessToken, json_encode($input)
        ]);
        
        error_log("Register with Identity - user_identity 建立成功");
        
        // 3. 生成推薦碼（如果沒有）
        $referralCode = generateReferralCode($db, $userId);
        
        // 4. 重新查詢用戶資料
        $stmt = $db->query("SELECT * FROM users WHERE id = ?", [$userId]);
        $user = $stmt->fetch();
        
        // 5. 生成 Access/Refresh Tokens
        $payload = [
            'user_id' => $user['id'],
            'email' => $user['email'],
            'name' => $user['name'],
        ];
        
        $tokenPair = JWTManager::generateTokenPair($payload);
        $token = $tokenPair['access_token'];
        
        // 6. 準備回應資料
        $userData = [
            'id' => $user['id'],
            'name' => $user['name'],
            'email' => $user['email'],
            'phone' => $user['phone'] ?? '',
            'nickname' => $user['nickname'] ?? '',
            'avatar_url' => $user['avatar_url'] ?? '',
            'points' => (int)($user['points'] ?? 0),
            'status' => $user['status'],
            'provider' => $provider,
            'created_at' => $user['created_at'],
            'updated_at' => $user['updated_at'],
            'referral_code' => $user['referral_code'] ?? '',
            'primary_language' => $user['primary_language'] ?? 'English',
            'permission' => (int)($user['permission'] ?? 0),
            'is_new_user' => true,
            'provider_user_id' => $providerUserId
        ];
        
        // 提交交易
        $db->commit();
        
        error_log("Register with Identity - 註冊成功，用戶 ID: {$user['id']}");
        
        echo json_encode([
            'success' => true,
            'message' => 'Registration successful',
            'data' => [
                'token' => $token,
                'access_token' => $token,
                'refresh_token' => $tokenPair['refresh_token'],
                'token_type' => $tokenPair['token_type'],
                'expires_in' => $tokenPair['expires_in'],
                'refresh_expires_in' => $tokenPair['refresh_expires_in'],
                'user' => $userData
            ]
        ]);
        
    } catch (Exception $e) {
        // 回滾交易
        $db->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Register with Identity Error: " . $e->getMessage());
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

/**
 * 生成推薦碼
 */
function generateReferralCode($db, $userId) {
    $maxAttempts = 10;
    $attempt = 0;
    
    do {
        $attempt++;
        $referralCode = strtoupper(substr(md5($userId . time() . $attempt), 0, 8));
        
        // 檢查推薦碼是否已存在
        $stmt = $db->query("SELECT id FROM users WHERE referral_code = ?", [$referralCode]);
        $existing = $stmt->fetch();
        
        if (!$existing) {
            // 更新用戶的推薦碼
            $db->query("UPDATE users SET referral_code = ? WHERE id = ?", [$referralCode, $userId]);
            return $referralCode;
        }
    } while ($attempt < $maxAttempts);
    
    // 如果無法生成唯一推薦碼，使用用戶 ID 作為後綴
    $referralCode = 'REF' . $userId;
    $db->query("UPDATE users SET referral_code = ? WHERE id = ?", [$referralCode, $userId]);
    return $referralCode;
}
?>
