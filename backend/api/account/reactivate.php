<?php
require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../auth_helper.php';

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
    // 驗證 JWT token（支援多種來源，以兼容 MAMP/FastCGI 環境）
    $jwtManager = new JWTManager();
    $authHeader = getAuthorizationHeader();
    $token = null;
    if ($authHeader && strpos($authHeader, 'Bearer ') === 0) {
        $token = trim(substr($authHeader, 7));
    }
    if (!$token) {
        // 查詢參數或 POST 體備援
        $token = $_GET['token'] ?? ($_POST['token'] ?? null);
    }
    if (!$token) {
        Response::badRequest('Token is required');
    }
    
    $payload = $jwtManager->validateToken($token);
    if (!$payload) {
        Response::unauthorized('Invalid or expired token');
    }
    
    $userId = $payload['user_id'];
    
    // 建立資料庫連線
    $pdo = new PDO("mysql:host=" . EnvLoader::get('DB_HOST') . ";dbname=" . EnvLoader::get('DB_NAME'), 
                   EnvLoader::get('DB_USERNAME'), EnvLoader::get('DB_PASSWORD'));
    
    // 檢查用戶當前狀態
    $stmt = $pdo->prepare("SELECT permission, status FROM users WHERE id = ?");
    $stmt->execute([$userId]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        Response::notFound('User not found');
    }
    
    // 只有自主停用的帳號可以重新啟用
    if ($user['permission'] != -3) {
        if ($user['permission'] == -1) {
            Response::forbidden('Account is suspended by administrator. Please contact customer service for assistance.');
        } else {
            Response::error(ErrorCodes::ACCOUNT_NOT_IN_DEACTIVATED_STATE);
        }
    }
    
    // 更新用戶狀態為正常
    $stmt = $pdo->prepare("
        UPDATE users 
        SET permission = 1,
            updated_at = NOW()
        WHERE id = ?
    ");
    $stmt->execute([$userId]);
    
    // 記錄操作日誌
    $stmt = $pdo->prepare("
        INSERT INTO user_active_log (user_id, actor_type, actor_id, action, field, old_value, new_value, reason, ip, created_at)
        VALUES (?, 'user', ?, 'reactivate', 'permission', ?, ?, 'User reactivated account', ?, NOW())
    ");
    $stmt->execute([
        $userId,
        $userId,
        $user['permission'],
        1,
        $_SERVER['REMOTE_ADDR'] ?? 'unknown'
    ]);
    
    Response::success([
        'user_id' => $userId,
        'permission' => 1,
        'status' => $user['status'],
        'reactivated_at' => date('Y-m-d H:i:s')
    ], 'Account has been reactivated successfully.');
    
} catch (Exception $e) {
    Response::badRequest($e->getMessage());
}
?>
