<?php
require_once __DIR__ . '/bootstrap.php';
// 載入 PHP 8.4 相容性配置

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

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
require_once __DIR__ . '/../../config/database.php';

try {
    // 獲取 POST 資料
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }
    
    $referralCode = strtoupper(trim($input['referral_code'] ?? ''));
    
    // 驗證輸入
    if (empty($referralCode)) {
        throw new Exception('Referral code is required');
    }
    
    // 建立資料庫連線
    $db = Database::getInstance();
    
    // 檢查推薦碼是否存在且擁有者為有效用戶（permission >= 1）
    $stmt = $db->query(
        "SELECT id, name, nickname, email, status, permission FROM users 
         WHERE referral_code = ?",
        [$referralCode]
    );
    
    $user = $stmt->fetch();
    
    if (!$user) {
        echo json_encode([
            'success' => false,
            'message' => 'Referral code is invalid or does not exist'
        ]);
        exit;
    }

    if (!PermissionHelper::isVerified($user['permission'] ?? 0)) {
        echo json_encode([
            'success' => false,
            'message' => 'Referral code owner is not an active verified user'
        ]);
        exit;
    }

    // 推薦碼有效
    echo json_encode([
        'success' => true,
        'message' => 'Referral code is valid',
        'data' => [
            'referrer_id' => (int)$user['id'],
            'referrer_name' => ($user['nickname'] ?: $user['name']) ?? '',
            'referrer_email' => $user['email'] ?? ''
        ]
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
