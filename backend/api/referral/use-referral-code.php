<?php
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
    
    // 檢查推薦碼是否存在且未使用
    $referralData = $db->fetch("
        SELECT rc.id, rc.user_id, rc.referral_code, rc.is_used, u.name, u.nickname
        FROM referral_codes rc
        JOIN users u ON rc.user_id = u.id
        WHERE rc.referral_code = ?
    ", [$referralCode]);
    
    if (!$referralData) {
        Response::error('Invalid referral code');
        exit;
    }
    
    if ($referralData['is_used']) {
        Response::error('Referral code has already been used');
        exit;
    }
    
    // 檢查是否自己使用自己的推薦碼
    if ($referralData['user_id'] == $newUserId) {
        Response::error('Cannot use your own referral code');
        exit;
    }
    
    // 開始事務
    $connection = $db->getConnection();
    $connection->beginTransaction();
    
    try {
        // 標記推薦碼為已使用
        $db->query("
            UPDATE referral_codes 
            SET is_used = 1, used_by_user_id = ?, updated_at = NOW()
            WHERE referral_code = ?
        ", [$newUserId, $referralCode]);
        
        // 這裡可以添加獎勵邏輯，例如給推薦人積分
        // $db->query("UPDATE users SET points = points + 100 WHERE id = ?", [$referralData['user_id']]);
        
        // 提交事務
        $connection->commit();
        
        Response::success('Referral code used successfully', [
            'referral_code' => $referralCode,
            'referrer_name' => $referralData['nickname'] ?: $referralData['name'],
            'used_by_user_id' => $newUserId
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