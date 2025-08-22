<?php
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
    
    // 檢查用戶是否已驗證
    if ($user['status'] !== 'verified') {
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
        
        // 更新用戶表
        $db->query("UPDATE users SET referral_code = ? WHERE id = ?", [$userId, $referralCode]);
        
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