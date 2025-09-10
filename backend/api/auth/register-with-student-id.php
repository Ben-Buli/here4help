<?php
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
}

try {
    $db = Database::getInstance();
    
    // 驗證必要欄位
    $requiredFields = [
        'name', 'gender', 'email', 'phone', 
         'address', 'password', 'date_of_birth', 
        'payment_password', 'school_name', 'student_name', 'student_id'
    ];
    
    foreach ($requiredFields as $field) {
        if (!isset($_POST[$field]) || empty($_POST[$field])) {
            Response::error("Missing required field: $field");
        }
    }
    
    // 檢查 email 是否已存在
    $email = $_POST['email'];
    $existingUser = $db->fetch("SELECT id FROM users WHERE email = ?", [$email]);
    if ($existingUser) {
        Response::error('Email already exists');
    }
    
    // 可選：推薦碼驗證（如有輸入）
    $introReferralCode = trim($_POST['intro_referral_code'] ?? '');
    $referrerId = null;
    if (!empty($introReferralCode)) {
        $ref = $db->fetch("SELECT id, status, permission FROM users WHERE referral_code = ?", [$introReferralCode]);
        if (!$ref) {
            Response::error('Invalid referral code');
        }
        $isStatusValid = in_array(strtolower($ref['status']), ['active', 'verified'], true);
        $isPermissionValid = (int)($ref['permission'] ?? 0) > 0;
        if (!($isStatusValid && $isPermissionValid)) {
            Response::error('Referral code owner is not active verified');
        }
        $referrerId = $ref['id'];
    }
    
    // 處理圖片上傳
    if (!isset($_FILES['student_id_image']) || $_FILES['student_id_image']['error'] !== UPLOAD_ERR_OK) {
        Response::error('Student ID image is required');
    }
    
    $uploadDir = '../../uploads/student_id_images/';
    if (!is_dir($uploadDir)) {
        mkdir($uploadDir, 0755, true);
    }
    
    $file = $_FILES['student_id_image'];
    $fileName = time() . '_' . uniqid() . '_' . basename($file['name']);
    $filePath = $uploadDir . $fileName;
    
    // 驗證檔案類型
    $allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif'];
    if (!in_array($file['type'], $allowedTypes)) {
        Response::error('Invalid file type. Only JPG, PNG, and GIF are allowed.');
    }
    
    // 驗證檔案大小 (最大 5MB)
    if ($file['size'] > 5 * 1024 * 1024) {
        Response::error('File size too large. Maximum size is 5MB.');
    }
    
    // 移動上傳的檔案
    if (!move_uploaded_file($file['tmp_name'], $filePath)) {
        Response::error('Failed to upload file');
    }
    
    // 開始資料庫交易
    $connection = $db->getConnection();
    $connection->beginTransaction();
    
    try {
        // 建立用戶帳戶
        $hashedPassword = password_hash($_POST['password'], PASSWORD_DEFAULT);
        $hashedPaymentPassword = password_hash($_POST['payment_password'], PASSWORD_DEFAULT);
        
        // 新用戶初始狀態為 permission = 0 (未驗證)
        $userSql = "INSERT INTO users (
            name, email, password, phone, points, status, permission,
            payment_password, date_of_birth, gender, country,
            address, is_permanent_address, primary_language, intro_referral_code,
            created_at, updated_at
        ) VALUES (?, ?, ?, ?, 0, 'pending_verification', 0, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())";
        
        $db->query($userSql, [
            $_POST['name'] ,
            $email,
            $hashedPassword,
            $_POST['phone'],
            $hashedPaymentPassword,
            $_POST['date_of_birth'],
            $_POST['gender'],
            $_POST['country'],
            $_POST['address'],
            $_POST['is_permanent_address'] ? 1 : 0,
            $_POST['primary_language'] ?? 'English',
            $introReferralCode ?: null
        ]);
        
        $userId = $db->lastInsertId();
        
        // 如果有推薦碼，記錄到日誌（等待管理員審核後發放獎勵）
        if (!empty($introReferralCode) && $referrerId) {
            error_log("學生證註冊時使用推薦碼：推薦人ID $referrerId，被推薦人ID $userId，推薦碼 $introReferralCode - 等待管理員審核後發放獎勵");
        }
        
        // 建立學生證驗證記錄
        $verificationSql = "INSERT INTO student_verifications (
            user_id, school_name, student_name, student_id, 
            student_id_image_path, verification_status, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, 'pending', NOW(), NOW())";
        
        $db->query($verificationSql, [
            $userId,
            $_POST['school_name'],
            $_POST['student_name'],
            $_POST['student_id'],
            'uploads/student_id_images/' . $fileName
        ]);
        
        // 提交交易
        $connection->commit();
        
        // 回傳成功回應
        Response::success([
            'user_id' => $userId,
            'message' => 'Registration successful. Please wait for verification.'
        ], 'Registration completed successfully', 201);
        
    } catch (Exception $e) {
        // 回滾交易
        $connection->rollback();
        
        // 刪除已上傳的檔案
        if (file_exists($filePath)) {
            unlink($filePath);
        }
        
        throw $e;
    }
    
} catch (Exception $e) {
    Response::serverError('Registration failed: ' . $e->getMessage());
}
?> 