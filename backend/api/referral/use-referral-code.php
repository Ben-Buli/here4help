<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
    exit;
}

try {
    $db = Database::getInstance();
    
    // 獲取 JSON 數據
    $input = json_decode(file_get_contents('php://input'), true);
    
    $referralCode = $input['referral_code'] ?? '';
    $newUserId = $input['user_id'] ?? null;
    
    if (empty($referralCode)) {
        Response::error('Referral code is required');
        exit;
    }
    
    if (!$newUserId) {
        Response::error('User ID is required');
        exit;
    }
    
    // 檢查推薦碼是否存在（含擁有者狀態/權限）
    $referralData = $db->fetch("
        SELECT rc.id, rc.user_id, rc.referral_code, rc.is_used, rc.used_by_user_id, u.name, u.nickname, u.status, u.permission
        FROM referral_codes rc
        JOIN users u ON rc.user_id = u.id
        WHERE rc.referral_code = ?
    ", [$referralCode]);
    
    if (!$referralData) {
        Response::error('Invalid referral code');
        exit;
    }
    
    // 檢查推薦碼擁有者是否為有效用戶（status 有效且 permission > 0）
    if (!(($referralData['status'] === 'active' || $referralData['status'] === 'verified') && ((int)$referralData['permission'] > 0))) {
        Response::error('Referral code is not active');
        exit;
    }
    
    // 檢查是否自己使用自己的推薦碼
    if ((int)$referralData['user_id'] === (int)$newUserId) {
        Response::error('Cannot use your own referral code');
        exit;
    }
    
    // 檢查是否已被其他用戶綁定（單次使用制）
    if (!empty($referralData['used_by_user_id'])) {
        Response::error('Referral code has already been referenced');
        exit;
    }
    
    // 開始事務
    $connection = $db->getConnection();
    $connection->beginTransaction();
    
    try {
        // 將這個推薦碼標記為被此新用戶引用（待管理員批准後才會發點數與最終生效）
        $db->query("
            UPDATE referral_codes
            SET used_by_user_id = ?, updated_at = NOW()
            WHERE id = ?
        ", [$newUserId, $referralData['id']]);
        
        // 提交事務
        $connection->commit();
        
        Response::success('Referral code referenced successfully (pending approval)', [
            'referral_code' => $referralCode,
            'referrer_name' => $referralData['nickname'] ?: $referralData['name'],
            'referred_user_id' => (int)$newUserId,
            'pending' => true
        ]);
        
    } catch (Exception $e) {
        // 回滾事務
        $connection->rollback();
        Response::error('Database error: ' . $e->getMessage());
    }
    
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage());
}
?> 