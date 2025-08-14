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
require_once '../../config/database.php';

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
    
    // 查詢用戶
    $stmt = $db->query(
        "SELECT * FROM users WHERE email = ? AND status = 'active'",
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
    
    // 生成 base64 編碼的 JSON Token
    $payload = [
        'user_id' => $user['id'],
        'email' => $user['email'],
        'name' => $user['name'],
        'iat' => time(),
        'exp' => time() + (60 * 60 * 24 * 7) // 7 天過期
    ];
    
    // 使用 base64 編碼 JSON 數據
    $token = base64_encode(json_encode($payload));
    
    // 驗證生成的 token 格式
    $decoded = base64_decode($token);
    $decodedPayload = json_decode($decoded, true);
    
    if (!$decodedPayload || !isset($decodedPayload['user_id'])) {
        throw new Exception('Token generation failed');
    }
    
    // 更新最後更新時間（因為沒有 last_login 欄位）
    $db->query(
        "UPDATE users SET updated_at = NOW() WHERE id = ?",
        [$user['id']]
    );
    
    // 準備回應資料
    $userData = [
        'id' => $user['id'],
        'name' => $user['name'] ?? '',
        'email' => $user['email'],
        'phone' => $user['phone'] ?? '',
        'nickname' => $user['nickname'] ?? '',
        'avatar_url' => $user['avatar_url'] ?? '',
        'points' => (int)($user['points'] ?? 0),
        'status' => $user['status'],
        'provider' => $user['provider'],
        'created_at' => $user['created_at'],
        'updated_at' => $user['updated_at'],
        'referral_code' => $user['referral_code'] ?? '',
        'primary_language' => $user['primary_language'] ?? 'English',
        'permission' => (int)($user['permission'] ?? 0)
    ];
    
    echo json_encode([
        'success' => true,
        'message' => 'Login successful',
        'data' => [
            'token' => $token,
            'user' => $userData
        ]
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
} 