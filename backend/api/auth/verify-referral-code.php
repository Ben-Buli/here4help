<?php
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
require_once '../../config/database.php';
require_once '../../utils/Response.php';

try {
    // 獲取 POST 資料
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }
    
    $referralCode = trim($input['referral_code'] ?? '');
    
    // 驗證輸入
    if (empty($referralCode)) {
        throw new Exception('Referral code is required');
    }
    
    // 建立資料庫連線
    $db = Database::getInstance();
    
    // 檢查推薦碼是否存在且對應用戶狀態為 active
    $stmt = $db->query(
        "SELECT id, name, status FROM users WHERE referral_code = ? AND status = 'active'",
        [$referralCode]
    );
    
    $user = $stmt->fetch();
    
    if ($user) {
        // 推薦碼有效
        echo json_encode([
            'success' => true,
            'message' => 'Referral code is valid',
            'data' => [
                'referrer_id' => $user['id'],
                'referrer_name' => $user['name']
            ]
        ]);
    } else {
        // 推薦碼無效或不存在
        echo json_encode([
            'success' => false,
            'message' => 'Referral code is invalid or does not exist'
        ]);
    }
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>

