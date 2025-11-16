<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../utils/TermsManager.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::methodNotAllowed('Method not allowed');
}

try {
    $db = Database::getInstance();

    $oauthToken = trim($_POST['oauth_token'] ?? '');
    if (empty($oauthToken)) {
        Response::validationError(['oauth_token' => 'OAuth token is required']);
    }

    $requiredFields = ['school_name', 'student_name', 'student_id'];
    $missing = [];
    foreach ($requiredFields as $field) {
        if (!isset($_POST[$field]) || trim((string)$_POST[$field]) === '') {
            $missing[$field] = 'This field is required';
        }
    }
    if (!empty($missing)) {
        Response::validationError($missing);
    }

    if (!isset($_FILES['student_id_image']) || $_FILES['student_id_image']['error'] !== UPLOAD_ERR_OK) {
        Response::validationError(['student_id_image' => 'Student ID image is required']);
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

    // 取得臨時 OAuth 資料
    $tempUser = $db->fetch(
        "SELECT * FROM oauth_temp_users WHERE token = ? AND expired_at > NOW()",
        [$oauthToken]
    );
    if (!$tempUser) {
        Response::error('OAuth token expired or invalid');
    }

    $tempRawData = json_decode($tempUser['raw_data'] ?? '[]', true) ?? [];

    $name = trim($_POST['name'] ?? $tempUser['name'] ?? '');
    $nickname = trim($_POST['nickname'] ?? $tempUser['name'] ?? '');
    $email = trim($_POST['email'] ?? $tempUser['email'] ?? '');
    $phone = trim($_POST['phone'] ?? '');
    $gender = trim($_POST['gender'] ?? 'Prefer not to disclose');
    $country = trim($_POST['country'] ?? '');
    $address = trim($_POST['address'] ?? '');
    $primaryLanguage = trim($_POST['primary_language'] ?? 'English');
    $isPermanentAddressRaw = $_POST['is_permanent_address'] ?? false;
    $isPermanentAddress = filter_var($isPermanentAddressRaw, FILTER_VALIDATE_BOOLEAN) ? 1 : 0;
    $introReferralCode = trim($_POST['intro_referral_code'] ?? '');
    $paymentPassword = $_POST['payment_password'] ?? null;
    $avatarUrl = trim($_POST['avatar_url'] ?? ($tempUser['avatar_url'] ?? ''));

    if (empty($name) || empty($email)) {
        Response::validationError(['name' => 'Name is required', 'email' => 'Email is required']);
    }

    // 驗證推薦碼
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

    // 已存在 email 檢查
    $existingUser = $db->fetch("SELECT id FROM users WHERE email = ?", [$email]);
    if ($existingUser) {
        Response::error('Email already exists');
    }

    // 上傳學生證圖片
    $uploadDir = '../../uploads/student_id_images/';
    if (!is_dir($uploadDir)) {
        mkdir($uploadDir, 0755, true);
    }

    $file = $_FILES['student_id_image'];
    $fileName = time() . '_' . uniqid() . '_' . basename($file['name']);
    $filePath = $uploadDir . $fileName;

    $allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif'];
    if (!in_array($file['type'], $allowedTypes)) {
        Response::validationError(['student_id_image' => 'Invalid file type. Only JPG, PNG, and GIF are allowed.']);
    }

    if ($file['size'] > 5 * 1024 * 1024) {
        Response::validationError(['student_id_image' => 'File size too large. Maximum size is 5MB.']);
    }

    if (!move_uploaded_file($file['tmp_name'], $filePath)) {
        Response::error('Failed to upload file');
    }

    $connection = $db->getConnection();
    $connection->beginTransaction();

    try {
        $generatedPassword = bin2hex(random_bytes(8));
        $hashedPassword = password_hash($generatedPassword, PASSWORD_DEFAULT);
        $hashedPaymentPassword = null;
        if (!empty($paymentPassword)) {
            $hashedPaymentPassword = password_hash($paymentPassword, PASSWORD_DEFAULT);
        }

        $insertUserSql = "
            INSERT INTO users (
                name, nickname, email, password, phone, points, status, permission,
                payment_password, date_of_birth, gender, country, address,
                is_permanent_address, primary_language, intro_referral_code,
                avatar_url, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, 0, 'pending_verification', 0, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
        ";

        $db->query($insertUserSql, [
            $name,
            $nickname ?: $name,
            $email,
            $hashedPassword,
            $phone,
            $hashedPaymentPassword,
            $_POST['date_of_birth'] ?? $tempUser['date_of_birth'],
            $gender,
            $country,
            $address,
            $isPermanentAddress,
            $primaryLanguage,
            $introReferralCode ?: null,
            $avatarUrl
        ]);

        $userId = $db->lastInsertId();

        $insertIdentitySql = "
            INSERT INTO user_identities (
                user_id, provider, provider_user_id, email, name, avatar_url,
                access_token, raw_profile, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
        ";

        $db->query($insertIdentitySql, [
            $userId,
            $tempUser['provider'],
            $tempUser['provider_user_id'],
            $email,
            $name,
            $avatarUrl,
            null,
            json_encode($tempRawData)
        ]);

        $db->query("DELETE FROM oauth_temp_users WHERE token = ?", [$oauthToken]);

        $db->query(
            "INSERT INTO student_verifications (
                user_id, school_name, student_name, student_id,
                student_id_image_path, verification_status, created_at, updated_at
             ) VALUES (?, ?, ?, ?, ?, 'pending', NOW(), NOW())",
            [
                $userId,
                trim($_POST['school_name']),
                trim($_POST['student_name']),
                trim($_POST['student_id']),
                'student_id_images/' . $fileName
            ]
        );

        if ($acceptedTermsVersionId !== null) {
            TermsManager::recordAcceptance($userId, $acceptedTermsVersionId, [
                'ip_address' => $_SERVER['REMOTE_ADDR'] ?? null,
                'platform' => $acceptedTermsPlatform,
                'device_info' => $acceptedTermsDeviceInfo,
                'user_agent' => $acceptedTermsUserAgent,
            ]);
        }

        $connection->commit();

        Response::success([
            'user_id' => $userId,
            'message' => 'Registration successful. Please wait for verification.'
        ], 'Registration completed successfully', 201);
    } catch (Exception $e) {
        $connection->rollback();
        if (file_exists($filePath)) {
            unlink($filePath);
        }
        throw $e;
    }
} catch (Exception $e) {
    Response::serverError('Registration failed: ' . $e->getMessage());
}
