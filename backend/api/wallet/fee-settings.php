<?php
require_once dirname(__DIR__, 2) . '/config/database.php'; // 因為 database.php 在 /backend/config/，要從 /backend/api/wallet 回到 /backend，需要往上兩層，再拼 /config/database.php 
require_once dirname(__DIR__, 2) . '/utils/response.php';
require_once dirname(__DIR__, 2) . '/utils/JWTManager.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::methodNotAllowed('Only GET method is allowed');
}

try {
    // 驗證 JWT
    $token = $_GET['token'] ?? null;
    if (!$token) {
        $headers = getallheaders();
        $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';
        if (preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
            $token = $matches[1];
        }
    }
    
    if (!$token) {
        Response::unauthorized('No token provided');
    }
    
    $userData = JWTManager::validateToken($token);
    
    if (!$userData) {
        Response::unauthorized('Invalid token');
    }
    
    $db = Database::getInstance();
    
    // 查詢啟用的手續費設定
    $sql = "SELECT * FROM task_completion_points_fee_settings WHERE is_active = 1 LIMIT 1";
    $feeSettings = $db->fetch($sql);
    
    if (!$feeSettings) {
        // 如果沒有啟用的設定，返回預設值
        $feeSettings = [
            'id' => 0,
            'rate' => 0.0,
            'is_active' => 0,
            'description' => 'No fee settings configured',
            'created_at' => date('Y-m-d H:i:s'),
            'updated_at' => date('Y-m-d H:i:s')
        ];
    }
    
    Response::success($feeSettings, 'Fee settings retrieved successfully');
    
} catch (Exception $e) {
    Response::serverError('Failed to retrieve fee settings: ' . $e->getMessage());
}
?>
