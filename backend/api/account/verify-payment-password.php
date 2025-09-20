<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../config/php84_compatibility.php';

require_once dirname(__DIR__, 2) . '/config/database.php';
require_once dirname(__DIR__, 2) . '/utils/response.php';
require_once dirname(__DIR__, 2) . '/utils/JWTManager.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::methodNotAllowed('Only POST method is allowed');
}

try {
    // 驗證 JWT token - 支持多源讀取
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
    
    $userId = $userData['user_id'];
    
    // 解析請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        Response::error('Invalid JSON input', 400);
    }
    
    $paymentPassword = $input['payment_password'] ?? '';
    
    // 驗證必要欄位
    if (empty($paymentPassword)) {
        Response::error('Payment password is required', 400);
    }
    
    // 驗證付款密碼格式（6位數字）
    if (!preg_match('/^\d{6}$/', $paymentPassword)) {
        Response::error('Payment password must be 6 digits', 400);
    }
    
    $db = Database::getInstance();
    
    // 查詢用戶的付款密碼
    $sql = "SELECT id, payment_password FROM users WHERE id = ? AND status != 'deleted'";
    $user = $db->fetch($sql, [$userId]);
    
    if (!$user) {
        Response::error('User not found', 404);
    }
    
    // 檢查是否設定了付款密碼
    if (empty($user['payment_password'])) {
        Response::error('Payment password not set. Please set your payment password first.', 400);
    }
    
    // 驗證付款密碼
    $isValid = password_verify($paymentPassword, $user['payment_password']);
    
    if (!$isValid) {
        Response::error('Invalid payment password', 401);
    }
    
    // 驗證成功
    Response::success([
        'user_id' => (int)$userId,
        'verified' => true,
        'message' => 'Payment password verified successfully'
    ], 'Payment password verification successful');
    
} catch (Exception $e) {
    Response::serverError('Payment password verification failed: ' . $e->getMessage());
}
?>
