<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

/**
 * GET /api/users/public-info.php?user_id=123
 * 獲取用戶公開資訊（姓名、頭像）
 * 用於 Resume Dialog 等需要顯示其他用戶基本資訊的場景
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../auth_helper.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    // 驗證JWT Token
    $tokenValidation = JWTManager::validateRequest();
    if (!$tokenValidation['valid']) {
        Response::error($tokenValidation['message'], 401);
    }
    
    // 檢查必要參數
    $targetUserId = $_GET['user_id'] ?? null;
    
    if (!$targetUserId || !is_numeric($targetUserId)) {
        Response::error('Valid user_id parameter is required', 400);
    }
    
    $db = Database::getInstance();
    
    // 獲取用戶公開資訊
    $userQuery = "
        SELECT 
            id,
            name,
            nickname,
            avatar_url
        FROM users 
        WHERE id = ? AND status = 'active'
    ";
    
    $user = $db->fetch($userQuery, [$targetUserId]);
    
    if (!$user) {
        Response::error('User not found or inactive', 404);
    }
    
    // 格式化回應資料
    $response = [
        'id' => (int)$user['id'],
        'name' => $user['name'] ?? '',
        'nickname' => $user['nickname'] ?? '',
        'avatar_url' => $user['avatar_url'] ?? '',
        'display_name' => !empty($user['name']) ? $user['name'] : ($user['nickname'] ?? 'User')
    ];
    
    Response::success($response, 'User public info retrieved successfully');
    
} catch (Exception $e) {
    error_log("User public info error: " . $e->getMessage());
    Response::error('Failed to retrieve user public info: ' . $e->getMessage(), 500);
}
?>
