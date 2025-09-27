<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

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
require_once __DIR__ . '/../../utils/Response.php';

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
    
    // 檢查推薦碼是否存在且擁有者為有效用戶（status 有效且 permission > 0）
    // 注意：部分資料庫內可能將 verified 與 active 作為不同標記，這裡兩者皆視為可用
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

    // 條件：擁有者狀態需為 active 或 verified，且 permission > 0（視為通過管理員核可的正式用戶）
    $isStatusValid = in_array(strtolower($user['status']), ['active', 'verified'], true);
    $isPermissionValid = (int)($user['permission'] ?? 0) > 0;

    if (!($isStatusValid && $isPermissionValid)) {
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

