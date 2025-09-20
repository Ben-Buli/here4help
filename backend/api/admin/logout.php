<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../config/php84_compatibility.php';

/**
 * 管理員登出 API
 * POST /api/admin/logout
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
}

try {
    // 驗證JWT Token
    $tokenData = JWTManager::validateRequest();
    if (!$tokenData['valid']) {
        Response::error($tokenData['message'], 401);
    }
    
    // 獲取 token 進行黑名單處理
    $token = null;
    
    // 從 Authorization header 獲取
    if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        $authHeader = $_SERVER['HTTP_AUTHORIZATION'];
        if (strpos($authHeader, 'Bearer ') === 0) {
            $token = trim(substr($authHeader, 7));
        }
    }
    
    // 從 GET/POST 參數獲取 (MAMP 兼容)
    if (!$token) {
        $token = $_GET['token'] ?? $_POST['token'] ?? '';
    }
    
    if ($token) {
        // 將 token 加入黑名單
        JWTManager::addToBlacklist($token);
    }
    
    Response::success([], 'Logout successful');
    
} catch (Exception $e) {
    error_log("Admin logout error: " . $e->getMessage());
    Response::error('Logout failed: ' . $e->getMessage(), 500);
}
?>
