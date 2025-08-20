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

// 引入必要的檔案
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';

// 載入環境配置
require_once __DIR__ . '/../../config/env_loader.php';

// 啟動 session 管理
session_start();

try {
    // 獲取 POST 資料
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }
    
    // 驗證必要參數
    $requiredFields = ['name', 'oauth_provider', 'provider_user_id'];
    foreach ($requiredFields as $field) {
        if (empty($input[$field])) {
            throw new Exception("Missing required field: $field");
        }
    }
    
    $name = trim($input['name']);
    $email = trim($input['email'] ?? '');
    $phone = trim($input['phone'] ?? '');
    $nickname = trim($input['nickname'] ?? '');
    $dateOfBirth = $input['date_of_birth'] ?? null;
    $gender = $input['gender'] ?? 'Prefer not to disclose';
    $country = trim($input['country'] ?? '');
    $address = trim($input['address'] ?? '');
    $isPermanentAddress = $input['is_permanent_address'] ?? false;
    $primaryLanguage = trim($input['primary_language'] ?? 'English');
    $school = trim($input['school'] ?? '');
    $referralCode = trim($input['referral_code'] ?? '');
    $paymentPassword = $input['payment_password'] ?? null;
    
    // OAuth 相關參數
    $oauthProvider = $input['oauth_provider'];
    $providerUserId = $input['provider_user_id'];
    $avatarUrl = $input['avatar_url'] ?? '';
    
    error_log("OAuth Register - 開始處理用戶註冊: $name, Provider: $oauthProvider");
    
    // 建立資料庫連線
    $db = Database::getInstance();
    
    // 檢查 session 中是否有暫存的 OAuth 資料
    if (!isset($_SESSION['oauth_temp_data']) || 
        $_SESSION['oauth_temp_data']['provider'] !== $oauthProvider ||
        $_SESSION['oauth_temp_data']['provider_user_id'] !== $providerUserId) {
        throw new Exception('OAuth session data not found or invalid');
    }
    
    $oauthData = $_SESSION['oauth_temp_data'];
    
    // 檢查 email 是否已存在（如果提供了 email）
    if (!empty($email)) {
        $stmt = $db->query(
            "SELECT * FROM users WHERE email = ?",
            [$email]
        );
        
        $existingUser = $stmt->fetch();
        if ($existingUser) {
            throw new Exception('Email already exists');
        }
    }
    
    // 檢查推薦碼（如果提供了）
    if (!empty($referralCode)) {
        $stmt = $db->query(
            "SELECT * FROM users WHERE referral_code = ?",
            [$referralCode]
        );
        
        $referrer = $stmt->fetch();
        if (!$referrer) {
            throw new Exception('Invalid referral code');
        }
    }
    
    // 開始資料庫交易
    $db->beginTransaction();
    
    try {
        // 第一步：建立 users 記錄
        $insertUserQuery = "
            INSERT INTO users (
                name, email, phone, nickname, date_of_birth, gender, 
                country, address, is_permanent_address, primary_language, 
                school, referral_code, payment_password, avatar_url, 
                status, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', NOW(), NOW())
        ";
        
        $db->query($insertUserQuery, [
            $name, $email, $phone, $nickname, $dateOfBirth, $gender,
            $country, $address, $isPermanentAddress, $primaryLanguage,
            $school, $referralCode, $paymentPassword, $avatarUrl
        ]);
        
        $userId = $db->lastInsertId();
        error_log("OAuth Register - 新用戶建立成功，用戶 ID: $userId");
        
        // 第二步：建立 user_identities 記錄
        $insertIdentityQuery = "
            INSERT INTO user_identities (
                user_id, provider, provider_user_id, email, name, avatar_url, 
                access_token, raw_profile, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
        ";
        
        $db->query($insertIdentityQuery, [
            $userId, $oauthProvider, $providerUserId, $email, $name, $avatarUrl,
            $oauthData['access_token'] ?? null, json_encode($oauthData['raw_profile'] ?? [])
        ]);
        
        error_log("OAuth Register - user_identity 建立成功");
        
        // 第三步：如果提供了推薦碼，處理推薦關係
        if (!empty($referralCode) && isset($referrer)) {
            // TODO: 實作推薦關係處理邏輯
            error_log("OAuth Register - 推薦關係處理（待實作）");
        }
        
        // 提交交易
        $db->commit();
        error_log("OAuth Register - 資料庫交易提交成功");
        
        // 生成 JWT Token
        $payload = [
            'user_id' => $userId,
            'email' => $email,
            'name' => $name,
            'iat' => time(),
            'exp' => time() + (60 * 60 * 24 * 7) // 7 天過期
        ];
        
        try {
            $token = JWTManager::generateToken($payload);
            error_log("OAuth Register - JWT token 生成成功，用戶: $userId");
        } catch (Exception $e) {
            error_log("OAuth Register - JWT token 生成失敗: " . $e->getMessage());
            throw new Exception('Token generation failed: ' . $e->getMessage());
        }
        
        // 清理 session 中的暫存資料
        unset($_SESSION['oauth_temp_data']);
        
        // 準備回應資料
        $userData = [
            'id' => $userId,
            'name' => $name,
            'email' => $email,
            'phone' => $phone,
            'nickname' => $nickname,
            'avatar_url' => $avatarUrl,
            'points' => 0,
            'status' => 'active',
            'provider' => $oauthProvider,
            'created_at' => date('Y-m-d H:i:s'),
            'updated_at' => date('Y-m-d H:i:s'),
            'referral_code' => $referralCode,
            'primary_language' => $primaryLanguage,
            'permission' => 0,
            'is_new_user' => true,
            'provider_user_id' => $providerUserId
        ];
        
        error_log("OAuth Register - 註冊成功，用戶 ID: $userId");
        
        echo json_encode([
            'success' => true,
            'message' => 'Registration successful',
            'data' => [
                'token' => $token,
                'user' => $userData
            ]
        ]);
        
    } catch (Exception $e) {
        // 回滾交易
        $db->rollback();
        error_log("OAuth Register - 資料庫交易回滾: " . $e->getMessage());
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("OAuth Register Error: " . $e->getMessage());
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
