<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once '../../middleware/AuthMiddleware.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
    exit;
}

try {
    // 驗證用戶身份
    $userId = AuthMiddleware::getUserId();
    if (!$userId) {
        Response::error('Unauthorized', 401);
        exit;
    }
    
    $db = Database::getInstance();
    
    // 獲取用戶資訊和推薦碼
    $user = $db->fetch("
        SELECT u.id, u.name, u.nickname, u.email, u.status, u.referral_code,
               rc.referral_code as generated_code, rc.is_used, rc.created_at
        FROM users u
        LEFT JOIN referral_codes rc ON u.id = rc.user_id
        WHERE u.id = ?
    ", [$userId]);
    
    if (!$user) {
        Response::error('User not found');
        exit;
    }
    
    // 檢查用戶是否為有效用戶：狀態有效且（若有 permission 欄位）permission > 0
    // 若無 permission 欄位，向後相容僅檢查狀態
    $isStatusOk = ($user['status'] === 'active' || $user['status'] === 'verified');
    $permissionOk = true;
    if (array_key_exists('permission', $user)) {
        $permissionOk = ((int)$user['permission']) > 0;
    }
    if (!($isStatusOk && $permissionOk)) {
        Response::error('User must be verified to get referral code');
        exit;
    }
    
    // 如果沒有推薦碼，生成一個
    if (!$user['referral_code'] && !$user['generated_code']) {
        // 生成唯一推薦碼
        do {
            $referralCode = strtoupper(substr(md5($userId . rand()), 0, 6));
            $exists = $db->fetch("SELECT COUNT(*) as count FROM referral_codes WHERE referral_code = ?", [$referralCode]);
        } while ($exists['count'] > 0);
        
        // 插入推薦碼記錄
        $db->query("INSERT INTO referral_codes (user_id, referral_code) VALUES (?, ?)", [$userId, $referralCode]);
        
        // 更新用戶表（參數順序修正）
        $db->query("UPDATE users SET referral_code = ? WHERE id = ?", [$referralCode, $userId]);
        
        $user['referral_code'] = $referralCode;
        $user['generated_code'] = $referralCode;
    }
    
    Response::success('Referral code retrieved successfully', [
        'user_id' => $user['id'],
        'user_name' => $user['nickname'] ?: $user['name'],
        'referral_code' => $user['referral_code'] ?: $user['generated_code'],
        'is_used' => $user['is_used'] ?: false,
        'created_at' => $user['created_at']
    ]);
    
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage());
}
?> 