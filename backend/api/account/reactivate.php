<?php
require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';

header('Content-Type: application/json');

try {
    // 驗證 JWT token
    $jwtManager = new JWTManager();
    $token = $_GET['token'] ?? null;
    
    if (!$token) {
        throw new Exception('Token is required');
    }
    
    $payload = $jwtManager->validateToken($token);
    if (!$payload) {
        throw new Exception('Invalid or expired token');
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
        throw new Exception('User not found');
    }
    
    // 只有自主停用的帳號可以重新啟用
    if ($user['permission'] != -3) {
        if ($user['permission'] == -1) {
            throw new Exception('Account is suspended by administrator. Please contact customer service for assistance.');
        } else {
            throw new Exception('Account is not in a deactivated state.');
        }
    }
    
    // 更新用戶狀態為正常
    $stmt = $pdo->prepare("
        UPDATE users 
        SET permission = 1, 
            status = 'active',
            updated_at = NOW()
        WHERE id = ?
    ");
    $stmt->execute([$userId]);
    
    // 記錄操作日誌
    $stmt = $pdo->prepare("
        INSERT INTO user_activity_logs (user_id, action, details, ip_address, created_at)
        VALUES (?, 'account_reactivated', 'User reactivated account', ?, NOW())
    ");
    $stmt->execute([$userId, $_SERVER['REMOTE_ADDR'] ?? 'unknown']);
    
    $response = [
        'success' => true,
        'message' => 'Account has been reactivated successfully.',
        'data' => [
            'user_id' => $userId,
            'permission' => 1,
            'status' => 'active',
            'reactivated_at' => date('Y-m-d H:i:s')
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
