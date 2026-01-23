<?php
require_once __DIR__ . '/bootstrap.php';
// 載入 PHP 8.4 相容性配置

/**
 * GET /api/admin/users/{user_id}/referral-info
 * 管理員獲取用戶推薦資訊 API
 */

require_once __DIR__ . '/../../../config/database.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    // 驗證JWT Token（需要管理員權限）
    $tokenData = JWTManager::validateRequest();
    if (!$tokenData['valid']) {
        Response::error($tokenData['message'], 401);
    }
    
    // 檢查管理員權限
    $adminId = $tokenData['admin_id'] ?? null;
    if (!$adminId) {
        Response::error('Admin access required', 403);
    }
    
    // 從 URL 路徑獲取 user_id
    $pathParts = explode('/', trim($_SERVER['REQUEST_URI'], '/'));
    $userIdIndex = array_search('users', $pathParts) + 1;
    $userId = isset($pathParts[$userIdIndex]) ? (int)$pathParts[$userIdIndex] : null;
    
    if (!$userId) {
        Response::error('User ID is required', 400);
    }
    
    $db = Database::getInstance()->getConnection();
    
    // 檢查用戶是否存在
    $userStmt = $db->prepare("
        SELECT id, name, email, permission, status, created_at 
        FROM users 
        WHERE id = ?
    ");
    $userStmt->execute([$userId]);
    $user = $userStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        Response::error('User not found', 404);
    }
    
    // 查找該用戶的推薦事件（作為被推薦人）
    $referralStmt = $db->prepare("
        SELECT 
            re.*,
            referrer.name as referrer_name,
            referrer.email as referrer_email,
            referrer.id as referrer_id
        FROM referral_events re
        JOIN users referrer ON re.referrer_id = referrer.id
        WHERE re.referee_id = ?
        ORDER BY re.created_at DESC
        LIMIT 1
    ");
    
    $referralStmt->execute([$userId]);
    $referralEvent = $referralStmt->fetch(PDO::FETCH_ASSOC);
    
    $responseData = null;
    
    if ($referralEvent) {
        $responseData = [
            'id' => (int)$referralEvent['id'],
            'referrer_id' => (int)$referralEvent['referrer_id'],
            'referrer_name' => $referralEvent['referrer_name'],
            'referrer_email' => $referralEvent['referrer_email'],
            'referral_code' => $referralEvent['referral_code'],
            'status' => $referralEvent['status'],
            'reward_points' => (int)$referralEvent['reward_points'],
            'created_at' => $referralEvent['created_at'],
            'completed_at' => $referralEvent['completed_at'],
            'notes' => $referralEvent['notes']
        ];
    }
    
    Response::success($responseData, 'User referral information retrieved successfully');
    
} catch (Exception $e) {
    error_log("Admin User Referral Info API Error: " . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}
?>
