<?php
require_once __DIR__ . '/bootstrap.php';
// 載入 PHP 8.4 相容性配置

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';
require_once __DIR__ . '/../../utils/TermsManager.php';
require_once __DIR__ . '/../../utils/AccountBlocker.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::methodNotAllowed();
}

try {
    $db = Database::getInstance();
    $pdo = $db->getConnection();
    
    // 驗證必要欄位
    $requiredFields = [
        'name',
        'gender',
        'email',
        'password',
        'date_of_birth',
        'payment_password',
        'address',
        'school_name',
        'student_name',
        'student_id',
    ];

    $missing = [];
    foreach ($requiredFields as $field) {
        if (!isset($_POST[$field]) || trim((string)$_POST[$field]) === '') {
            $missing[$field] = 'This field is required';
        }
    }

    if (!empty($missing)) {
        Response::validationError($missing);
    }

    $acceptedTermsVersionId = isset($_POST['accepted_terms_version_id'])
        ? (int)$_POST['accepted_terms_version_id']
        : null;
    $acceptedTermsPlatform = isset($_POST['accepted_terms_platform']) ? trim((string)$_POST['accepted_terms_platform']) : null;
    $acceptedTermsDeviceInfo = isset($_POST['accepted_terms_device_info']) ? trim((string)$_POST['accepted_terms_device_info']) : null;
    $acceptedTermsUserAgent = isset($_POST['accepted_terms_user_agent'])
        ? trim((string)$_POST['accepted_terms_user_agent'])
        : ($_SERVER['HTTP_USER_AGENT'] ?? null);

    if ($acceptedTermsVersionId !== null) {
        if ($acceptedTermsVersionId <= 0) {
            Response::validationError(['accepted_terms_version_id' => 'Invalid terms version']);
        }

        $terms = TermsManager::getTermsById($acceptedTermsVersionId);
        if (!$terms || (int)$terms['is_active'] !== 1) {
            Response::validationError(['accepted_terms_version_id' => 'Terms version is not active or does not exist']);
        }
    }

    // 取得並標準化輸入資料
    $name = trim($_POST['name']);
    $nickname = isset($_POST['nickname']) ? trim((string)$_POST['nickname']) : null;
    $gender = trim($_POST['gender']);
    $email = trim($_POST['email']);
    if (AccountBlocker::isEmailBlocked($pdo, $email)) {
        Response::forbidden('ACCOUNT_DELETED_BY_ADMIN');
    }
    $phone = isset($_POST['phone']) ? trim((string)$_POST['phone']) : '';
    $country = isset($_POST['country']) ? trim((string)$_POST['country']) : '';
    $address = trim($_POST['address']);
    $password = (string)$_POST['password'];
    $dateOfBirth = trim($_POST['date_of_birth']);
    $paymentPassword = (string)$_POST['payment_password'];
    $primaryLanguage = isset($_POST['primary_language']) && $_POST['primary_language'] !== ''
        ? trim((string)$_POST['primary_language'])
        : 'English';
    $isPermanentAddressRaw = $_POST['is_permanent_address'] ?? false;
    $isPermanentAddress = filter_var($isPermanentAddressRaw, FILTER_VALIDATE_BOOLEAN) ? 1 : 0;
    $schoolName = trim($_POST['school_name']);
    $studentName = trim($_POST['student_name']);
    $studentId = trim($_POST['student_id']);

    // 檢查 email 是否已存在
    $existingUser = $db->fetch("SELECT id FROM users WHERE email = ? AND permission NOT IN (-2, -4) ", [$email]); // 排除管理員刪除用戶、自已刪除的用戶
    if ($existingUser) {
        Response::error(ErrorCodes::EMAIL_ALREADY_EXISTS);
    }
    
    // 可選：推薦碼驗證（如有輸入）
    $introReferralCode = strtoupper(trim($_POST['intro_referral_code'] ?? ''));
    $referrerId = null;
    if (!empty($introReferralCode)) {
        $ref = $db->fetch("SELECT id, status, permission FROM users WHERE referral_code = ?", [$introReferralCode]);
        if (!$ref) {
            Response::error(ErrorCodes::INVALID_PARAMETER, 'Invalid referral code');
        }
        if (!PermissionHelper::isVerified($ref['permission'] ?? 0)) {
            Response::error(ErrorCodes::INVALID_REQUEST, 'Referral code owner is not active verified');
        }
        $referrerId = $ref['id'];
    }
    
    // 處理圖片上傳
    if (!isset($_FILES['student_id_image']) || $_FILES['student_id_image']['error'] !== UPLOAD_ERR_OK) {
        Response::validationError(['student_id_image' => 'Student ID image is required']);
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
        Response::validationError(['student_id_image' => 'Invalid file type. Only JPG, PNG, and GIF are allowed.']);
    }
    
    // 驗證檔案大小 (最大 5MB)
    if ($file['size'] > 5 * 1024 * 1024) {
        Response::validationError(['student_id_image' => 'File size too large. Maximum size is 5MB.']);
    }
    
    // 移動上傳的檔案
    if (!move_uploaded_file($file['tmp_name'], $filePath)) {
        Response::error(ErrorCodes::FILE_UPLOAD_FAILED, 'Failed to upload file');
    }
    
    // 開始資料庫交易
    $connection = $db->getConnection();
    $connection->beginTransaction();
    
    try {
        // 建立用戶帳戶
        $hashedPassword = password_hash($password, PASSWORD_DEFAULT);
        $hashedPaymentPassword = password_hash($paymentPassword, PASSWORD_DEFAULT);
        $nicknameForInsert = ($nickname !== null && $nickname !== '') ? $nickname : $name;
        
        // 新用戶初始狀態為 permission = 0 (未驗證)
        $userSql = "INSERT INTO users (
            name, nickname, email, password, phone, points, status, permission,
            payment_password, date_of_birth, gender, country,
            address, is_permanent_address, primary_language, intro_referral_code,
            created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, 0, 'pending_verification', 0, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())";
        
        $db->query($userSql, [
            $name,
            $nicknameForInsert,
            $email,
            $hashedPassword,
            $phone,
            $hashedPaymentPassword,
            $dateOfBirth,
            $gender,
            $country,
            $address,
            $isPermanentAddress,
            $primaryLanguage,
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
            $schoolName,
            $studentName,
            $studentId,
            'student_id_images/' . $fileName
        ]);
        
        // 若提供條款版本，記錄使用者同意
        if ($acceptedTermsVersionId !== null) {
            TermsManager::recordAcceptance($userId, $acceptedTermsVersionId, [
                'ip_address' => $_SERVER['REMOTE_ADDR'] ?? null,
                'platform' => $acceptedTermsPlatform,
                'device_info' => $acceptedTermsDeviceInfo,
                'user_agent' => $acceptedTermsUserAgent,
            ]);
        }

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
