<?php
// 載入 PHP 8.4 相容性配置
// require_once __DIR__ . '/../../config/php84_compatibility.php';

// 啟用輸出緩衝，避免任何非 JSON 前置輸出破壞回應
ob_start();

// 統一安全輸出 JSON 的輔助函式
if (!function_exists('send_json')) {
    function send_json(array $payload, int $statusCode = 200): void {
        // 清空任何已存在的輸出內容，確保回應是乾淨的 JSON
        if (ob_get_length()) {
            ob_clean();
        }
        http_response_code($statusCode);
        header('Content-Type: application/json');
        echo json_encode($payload);
        exit;
    }
}

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    send_json(['success' => true, 'message' => 'OK'], 200);
}

// 只允許 POST 請求（錯誤也回 200 + success=false）
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    send_json(['success' => false, 'message' => 'Method not allowed'], 200);
}

// 引入資料庫配置
require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';
require_once __DIR__ . '/../../utils/JWTManager.php';

// 確保環境配置已載入
EnvLoader::load();

try {
    // 獲取 POST 資料
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }
    
    $email = trim($input['email'] ?? '');
    $password = $input['password'] ?? '';
    
    // 驗證輸入
    if (empty($email) || empty($password)) {
        throw new Exception('Email and password are required');
    }
    
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        throw new Exception('Invalid email format');
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
        throw new Exception('Invalid email or password');
    }
    
    // 驗證密碼
    if (!password_verify($password, $user['password'])) {
        throw new Exception('Invalid email or password');
    }
    
    // 統一使用 permission 作為登入判斷：允許 permission >= 0 或 permission = -1, -3 登入
    // -1: 管理員停權（可登入但功能受限）
    // -3: 用戶自行停用（可登入但功能受限）
    // -2, -4: 軟刪除（不可登入）
    $userPermission = (int)($user['permission']);
    error_log("User permission: " . $userPermission);
    if ($userPermission < 0 && $userPermission != -1 && $userPermission != -3) {
        // 根據不同的刪除類型返回對應的錯誤訊息
        if ($userPermission == -2) {
            throw new Exception('This account has been removed by an administrator and cannot be used. Please contact support if you believe this is an error.');
        } elseif ($userPermission == -4) {
            throw new Exception('This account has been deleted and cannot be used. If you wish to use our service again, please create a new account.');
        } else {
            throw new Exception('Account is not allowed to login (permission)');
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
        throw new Exception('Token generation failed: ' . $e->getMessage());
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
    
    send_json([
        'success' => true,
        'message' => 'Login successful',
        'data' => [
            'token' => $token,
            'access_token' => $token,
            'refresh_token' => $tokenPair['refresh_token'],
            'token_type' => $tokenPair['token_type'],
            'expires_in' => $tokenPair['expires_in'],
            'refresh_expires_in' => $tokenPair['refresh_expires_in'],
            'user' => $userData
        ]
    ], 200);
    
} catch (Exception $e) {
    // 錯誤統一回 200 + success=false，避免瀏覽器以 CORS/非 2xx 視為網路錯誤
    send_json([
        'success' => false,
        'message' => $e->getMessage()
    ], 200);
}
