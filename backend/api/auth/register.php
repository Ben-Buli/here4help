<?php
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
    exit;
}

try {
    $db = Database::getInstance();
    
    // 獲取 JSON 數據
    $input = json_decode(file_get_contents('php://input'), true);
    
    // 驗證必要欄位
    $requiredFields = [
        'address', 'password', 'date_of_birth', 
        'payment_password', 'primary_language'
    ];
    
    foreach ($requiredFields as $field) {
        if (!isset($input[$field]) || empty($input[$field])) {
            Response::error("Missing required field: $field");
            exit;
        }
    }
    
    // 檢查 email 是否已存在
    $email = $input['email'];
    $existingUser = $db->fetch("SELECT id FROM users WHERE email = ?", [$email]);
    if ($existingUser) {
        Response::error('Email already exists');
        exit;
    }
    
    // 可選：推薦碼驗證（如有輸入）
    $introReferralCode = trim($input['intro_referral_code'] ?? '');
    $referrerId = null;
    if (!empty($introReferralCode)) {
        $ref = $db->fetch("SELECT id, status, permission FROM users WHERE referral_code = ?", [$introReferralCode]);
        if (!$ref) {
            Response::error('Invalid referral code');
            exit;
        }
        $isStatusValid = in_array(strtolower($ref['status']), ['active', 'verified'], true);
        $isPermissionValid = (int)($ref['permission'] ?? 0) > 0;
        if (!($isStatusValid && $isPermissionValid)) {
            Response::error('Referral code owner is not active verified');
            exit;
        }
        $referrerId = $ref['id'];
    }

    // 開始資料庫交易
    $connection = $db->getConnection();
    $connection->beginTransaction();
    
    try {
        // 建立用戶帳戶
        $hashedPassword = password_hash($input['password'], PASSWORD_DEFAULT);
        $hashedPaymentPassword = password_hash($input['payment_password'], PASSWORD_DEFAULT);
        
        // 新用戶初始狀態為 permission = 0 (未驗證)
        $userSql = "INSERT INTO users (
            name, nickname, email, password, phone, points, status, permission,
            payment_password, date_of_birth, gender, country,
            address, is_permanent_address, primary_language, intro_referral_code,
            created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, 0, 'active', 0, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())";
        
        $db->query($userSql, [
            $input['name'],
            $input['nickname'],
            $email,
            $hashedPassword,
            $input['phone'],
            $hashedPaymentPassword,
            $input['date_of_birth'],
            $input['gender'],
            $input['country'],
            $input['address'],
            $input['is_permanent_address'] ? 1 : 0,
            $input['primary_language'],
            $introReferralCode ?: null
        ]);
        
        $userId = $db->lastInsertId();
        
        // 如果有推薦碼，記錄到日誌（等待管理員審核後發放獎勵）
        if (!empty($introReferralCode) && $referrerId) {
            error_log("用戶註冊時使用推薦碼：推薦人ID $referrerId，被推薦人ID $userId，推薦碼 $introReferralCode - 等待管理員審核後發放獎勵");
        }
        
        // 提交交易
        $connection->commit();
        
        Response::success([
            'user_id' => $userId,
            'email' => $email,
            'status' => 'active'
        ], 'User registered successfully');
        
    } catch (Exception $e) {
        // 回滾交易
        $connection->rollback();
        Response::error('Database error: ' . $e->getMessage());
    }
    
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage());
}
?> 