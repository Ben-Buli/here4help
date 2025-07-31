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
    
    $google_id = $input['google_id'] ?? '';
    $email = trim($input['email'] ?? '');
    $name = trim($input['name'] ?? '');
    $avatar_url = $input['avatar_url'] ?? '';
    
    // 驗證輸入
    if (empty($google_id) || empty($email) || empty($name)) {
        throw new Exception('Google ID, email and name are required');
    }
    
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        throw new Exception('Invalid email format');
    }
    
    // 建立資料庫連線
    $db = Database::getInstance();
    
    // 檢查用戶是否已存在
    $stmt = $db->query(
        "SELECT * FROM users WHERE google_id = ? OR email = ?",
        [$google_id, $email]
    );
    
    $user = $stmt->fetch();
    
    if ($user) {
        // 用戶已存在，更新 Google ID 如果沒有
        if (empty($user['google_id'])) {
            $db->query(
                "UPDATE users SET google_id = ? WHERE id = ?",
                [$google_id, $user['id']]
            );
        }
        
            // 更新最後更新時間（因為沒有 last_login 欄位）
    $db->query(
        "UPDATE users SET updated_at = NOW() WHERE id = ?",
        [$user['id']]
    );
    } else {
        // 建立新用戶
        $db->query(
            "INSERT INTO users (google_id, email, name, avatar_url, is_verified, status, created_at) VALUES (?, ?, ?, ?, 1, 'active', NOW())",
            [$google_id, $email, $name, $avatar_url]
        );
        
        $user_id = $db->lastInsertId();
        
        // 重新查詢用戶資料
        $stmt = $db->query("SELECT * FROM users WHERE id = ?", [$user_id]);
        $user = $stmt->fetch();
    }
    
    // 生成 JWT Token
    $payload = [
        'user_id' => $user['id'],
        'email' => $user['email'],
        'name' => $user['name'],
        'iat' => time(),
        'exp' => time() + (60 * 60 * 24 * 7) // 7 天過期
    ];
    
    // 暫時使用簡單的 base64 編碼作為示例
    $token = base64_encode(json_encode($payload));
    
    // 準備回應資料
    $userData = [
        'id' => $user['id'],
        'name' => $user['name'] ?? '',
        'email' => $user['email'],
        'phone' => $user['phone'] ?? '',
        'nickname' => $user['nickname'] ?? '',
        'google_id' => $user['google_id'] ?? '',
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
        'message' => 'Google login successful',
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