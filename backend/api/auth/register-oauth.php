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
    $requiredFields = ['name', 'oauth_token'];
    foreach ($requiredFields as $field) {
        if (empty($input[$field])) {
            throw new Exception("Missing required field: $field");
        }
    }
    
    $oauthToken = trim($input['oauth_token']);
    $name = trim($input['name']);
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
    
    error_log("OAuth Register - 開始處理用戶註冊: $name, Token: " . substr($oauthToken, 0, 8) . "...");
    
    // 建立資料庫連線
    $db = Database::getInstance();
    
    // 第一步：從 oauth_temp_users 表獲取並消費 token
    $stmt = $db->query(
        "SELECT * FROM oauth_temp_users WHERE token = ? AND expired_at > NOW()",
        [$oauthToken]
    );
    
    $tempUser = $stmt->fetch();
    if (!$tempUser) {
        throw new Exception('OAuth token expired or invalid');
    }
    
    // 獲取 OAuth 資料
    $oauthProvider = $tempUser['provider'];
    $providerUserId = $tempUser['provider_user_id'];
    $email = $tempUser['email'];
    $avatarUrl = $tempUser['avatar_url'] ?? '';
    $rawData = json_decode($tempUser['raw_data'], true) ?? [];
    
    error_log("OAuth Register - 找到臨時用戶資料，Provider: $oauthProvider, Email: $email");
    
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
            null, // access_token 不再從 rawData 獲取
            json_encode($rawData)
        ]);
        
        error_log("OAuth Register - user_identity 建立成功");
        
        // 第三步：刪除臨時 token（消費）
        $db->query("DELETE FROM oauth_temp_users WHERE token = ?", [$oauthToken]);
        error_log("OAuth Register - 臨時 token 已消費刪除");
        
        // 第四步：如果提供了推薦碼，處理推薦關係
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
        
        // Token 已在交易中刪除，無需額外清理
        
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
