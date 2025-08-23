<?php
require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/UserActiveLogger.php';

// CORS headers
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Preflight
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    echo json_encode(['success' => true, 'message' => 'OK']);
    exit;
}

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Method not allowed');
    }

    // 驗證 JWT token - 支持多源讀取（Authorization header 和查詢參數）
    $jwtManager = new JWTManager();
    
    // 嘗試從 Authorization header 讀取
    $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    $token = str_replace('Bearer ', '', $authHeader);
    
    // 如果 header 中沒有 token，嘗試從查詢參數讀取（MAMP 兼容性）
    if (!$token) {
        $token = $_GET['token'] ?? $_POST['token'] ?? '';
    }
    
    if (!$token) {
        throw new Exception('Token is required');
    }
    
    $payload = $jwtManager->validateToken($token);
    if (!$payload) {
        throw new Exception('Invalid or expired token');
    }
    
    $userId = $payload['user_id'];
    
    // 解析請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }
    
    $currentPassword = $input['current_password'] ?? '';
    $newPassword = $input['new_password'] ?? '';
    $confirmPassword = $input['confirm_password'] ?? '';
    
    // 驗證必要欄位
    if (empty($currentPassword)) {
        throw new Exception('Current password is required');
    }
    
    if (empty($newPassword)) {
        throw new Exception('New password is required');
    }
    
    if (empty($confirmPassword)) {
        throw new Exception('Password confirmation is required');
    }
    
    if ($newPassword !== $confirmPassword) {
        throw new Exception('New password and confirmation do not match');
    }
    
    // 密碼強度檢查
    if (strlen($newPassword) < 8) {
        throw new Exception('Password must be at least 8 characters long');
    }
    
    if (!preg_match('/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/', $newPassword)) {
        throw new Exception('Password must contain at least one uppercase letter, one lowercase letter, and one number');
    }
    
    // 建立資料庫連線
    $pdo = new PDO("mysql:host=" . EnvLoader::get('DB_HOST') . ";dbname=" . EnvLoader::get('DB_NAME'), 
                   EnvLoader::get('DB_USERNAME'), EnvLoader::get('DB_PASSWORD'));
    
    // 查詢用戶當前密碼
    $stmt = $pdo->prepare("SELECT password FROM users WHERE id = ?");
    $stmt->execute([$userId]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        throw new Exception('User not found');
    }
    
    // 驗證當前密碼
    if (!password_verify($currentPassword, $user['password'])) {
        throw new Exception('Current password is incorrect');
    }
    
    // 檢查新密碼是否與當前密碼相同
    if (password_verify($newPassword, $user['password'])) {
        throw new Exception('New password must be different from current password');
    }
    
    // 更新密碼
    $hashedNewPassword = password_hash($newPassword, PASSWORD_DEFAULT);
    
    $updateStmt = $pdo->prepare("
        UPDATE users 
        SET password = ?, updated_at = NOW() 
        WHERE id = ?
    ");
    
    $updateStmt->execute([$hashedNewPassword, $userId]);

    UserActiveLogger::logAction($pdo, $userId, 'password_changed', 'password', null, null, 'User changed password');
    
    $response = [
        'success' => true,
        'message' => 'Password changed successfully',
        'data' => [
            'changed_at' => date('Y-m-d H:i:s')
        ]
    ];
    
    echo json_encode($response);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
