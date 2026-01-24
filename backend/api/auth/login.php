<?php
require_once __DIR__ . '/bootstrap.php';
// 載入 PHP 8.4 相容性配置

// 啟用輸出緩衝，避免任何非 JSON 前置輸出破壞回應
ob_start();

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    Response::success(null, 'OK', 200);
}

// 只允許 POST 請求（錯誤也回 200 + success=false）
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::methodNotAllowed('Method not allowed');
}

// 引入資料庫配置
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';

// 確保環境配置已載入
EnvLoader::load();

try {
    // 獲取 POST 資料
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        Response::error(ErrorCodes::INVALID_JSON, 'Invalid JSON input');
    }
    
    $email = trim($input['email'] ?? '');
    $password = $input['password'] ?? '';
    
    // 驗證輸入
    if (empty($email) || empty($password)) {
        Response::badRequest('Email and password are required');
    }
    
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        Response::badRequest('Invalid email format');
    }
    
    // 建立資料庫連線
    $db = Database::getInstance();
    
    // 查詢用戶（統一以 permission 做登入判斷，不再依賴 status）
    $stmt = $db->query(
        "SELECT * FROM users WHERE email = ?",
        [$email]
    );
    
    $user = $stmt->fetch();
    
    if (!$user) {
        Response::error(ErrorCodes::LOGIN_FAILED, 'Invalid email or password');
    }
    
    // 驗證密碼
    if (!password_verify($password, $user['password'])) {
        Response::error(ErrorCodes::LOGIN_FAILED, 'Invalid email or password');
    }
    
    // 統一使用 permission 作為登入判斷：僅允許 permission >= 0 或 permission = -1 登入
    // -1: 管理員停權（可登入但功能受限）
    // -2: 管理員移除（不可登入）
    // -3: 用戶自行停用（不可登入）
    // -4: 用戶自行刪除（不可登入）
    $userPermission = (int)($user['permission']);
    error_log("User permission: " . $userPermission);
    if ($userPermission < 0 && $userPermission != -1) {
        if ($userPermission == -2) {
            Response::error(
                ErrorCodes::ACCOUNT_DELETED,
                'ACCOUNT_DELETED_BY_ADMIN',
                ['reason' => 'admin']
            );
        } elseif ($userPermission == -3) {
            Response::error(
                ErrorCodes::ACCOUNT_SUSPENDED,
                'ACCOUNT_DISABLED_BY_USER',
                ['reason' => 'user']
            );
        } elseif ($userPermission == -4) {
            Response::error(
                ErrorCodes::ACCOUNT_DELETED,
                'ACCOUNT_DELETED_BY_USER',
                ['reason' => 'user']
            );
        } else {
            Response::error(
                ErrorCodes::INSUFFICIENT_PERMISSION,
                'ACCOUNT_NOT_ALLOWED'
            );
        }
    }
    
    // 生成 Access/Refresh Token
    $payload = [
        'user_id' => $user['id'],
        'email' => $user['email'],
        'name' => $user['name'],
        'permission' => $userPermission,
    ];

    try {
        $tokenPair = JWTManager::generateTokenPair($payload);
        $token = $tokenPair['access_token'];
    } catch (Exception $e) {
        error_log("JWT token generation failed: " . $e->getMessage());
        Response::serverError('Token generation failed: ' . $e->getMessage());
    }
    
    // 更新最後更新時間（因為沒有 last_login 欄位）
    $db->query(
        "UPDATE users SET updated_at = NOW() WHERE id = ?",
        [$user['id']]
    );
    
    // 準備回應資料
    $userData = [
        'id' => (int)($user['id'] ?? 0),
        'name' => $user['name'] ?? '',
        'email' => $user['email'] ?? '',
        'phone' => $user['phone'] ?? '',
        'nickname' => $user['nickname'] ?? '',
        'avatar_url' => $user['avatar_url'] ?? '',
        'points' => (int)($user['points'] ?? 0),
        'status' => $user['status'] ?? 'active',
        'provider' => null, // 傳統登入，provider 為 null
        'google_id' => null, // 已棄用，設為 null
        'created_at' => $user['created_at'] ?? '',
        'updated_at' => $user['updated_at'] ?? '',
        'referral_code' => $user['referral_code'] ?? '',
        'primary_language' => $user['primary_language'] ?? 'English',
        'permission' => (int)($user['permission'] ?? 0)
    ];
    
    Response::success([
        'token' => $token,
        'access_token' => $token,
        'refresh_token' => $tokenPair['refresh_token'],
        'token_type' => $tokenPair['token_type'],
        'expires_in' => $tokenPair['expires_in'],
        'refresh_expires_in' => $tokenPair['refresh_expires_in'],
        'user' => $userData
    ], 'Login successful', 200);
    
} catch (Exception $e) {
    Response::serverError($e->getMessage());
}
