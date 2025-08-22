<?php
require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';

header('Content-Type: application/json');

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Method not allowed');
    }

    // 驗證 JWT token
    $jwtManager = new JWTManager();
    $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    $token = str_replace('Bearer ', '', $authHeader);
    
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
    
    $password = $input['password'] ?? '';
    $reason = $input['reason'] ?? '';
    
    // 驗證必要欄位
    if (empty($password)) {
        throw new Exception('Password confirmation is required');
    }
    
    if (empty($reason)) {
        throw new Exception('Deletion reason is required');
    }
    
    // 建立資料庫連線
    $pdo = new PDO("mysql:host=" . EnvLoader::get('DB_HOST') . ";dbname=" . EnvLoader::get('DB_NAME'), 
                   EnvLoader::get('DB_USERNAME'), EnvLoader::get('DB_PASSWORD'));
    
    // 查詢用戶資料
    $stmt = $pdo->prepare("SELECT password, permission, status FROM users WHERE id = ?");
    $stmt->execute([$userId]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        throw new Exception('User not found');
    }
    
    // 驗證密碼
    if (!password_verify($password, $user['password'])) {
        throw new Exception('Password is incorrect');
    }
    
    // 檢查用戶是否已被管理員停權
    if ($user['permission'] == -1 || $user['status'] == 'banned') {
        throw new Exception('Account is suspended by administrator. Please contact support for account deletion.');
    }
    
    // 檢查是否有活躍的任務
    $activeTasksStmt = $pdo->prepare("
        SELECT COUNT(*) as count FROM tasks t
        LEFT JOIN task_statuses ts ON t.status_id = ts.id
        WHERE (t.creator_id = ? OR EXISTS (
            SELECT 1 FROM task_applications ta 
            WHERE ta.task_id = t.id AND ta.user_id = ? AND ta.status = 'accepted'
        ))
        AND ts.code NOT IN ('completed', 'cancelled')
        AND t.deleted_at IS NULL
    ");
    $activeTasksStmt->execute([$userId, $userId]);
    $activeTasksCount = $activeTasksStmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    if ($activeTasksCount > 0) {
        throw new Exception('Cannot delete account with active tasks. Please complete or cancel all active tasks first.');
    }
    
    // 檢查是否有活躍的聊天室
    $activeChatStmt = $pdo->prepare("
        SELECT COUNT(*) as count FROM chat_rooms cr
        WHERE cr.user_id = ? OR cr.participant_id = ?
        AND cr.status = 'active'
    ");
    $activeChatStmt->execute([$userId, $userId]);
    $activeChatCount = $activeChatStmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    if ($activeChatCount > 0) {
        throw new Exception('Cannot delete account with active chat rooms. Please close all active conversations first.');
    }
    
    // 開始資料庫交易
    $pdo->beginTransaction();
    
    try {
        // 軟刪除用戶（設置為自行軟刪除狀態）
        $updateStmt = $pdo->prepare("
            UPDATE users 
            SET permission = -4, 
                status = 'self_deleted', 
                deleted_at = NOW(),
                updated_at = NOW()
            WHERE id = ?
        ");
        
        $updateStmt->execute([$userId]);
        
        // 記錄刪除原因和操作日誌
        $logSql = "
            INSERT INTO user_activity_logs (user_id, action, details, ip_address, created_at)
            VALUES (?, 'account_deleted', ?, ?, NOW())
        ";
        
        $logStmt = $pdo->prepare($logSql);
        $logStmt->execute([
            $userId, 
            json_encode([
                'reason' => $reason,
                'deleted_at' => date('Y-m-d H:i:s'),
                'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? 'unknown'
            ]),
            $_SERVER['REMOTE_ADDR'] ?? 'unknown'
        ]);
        
        // 匿名化敏感資料（可選，根據隱私政策決定）
        $anonymizeStmt = $pdo->prepare("
            UPDATE users 
            SET email = CONCAT('deleted_', id, '@deleted.local'),
                phone = NULL,
                avatar_url = NULL
            WHERE id = ?
        ");
        $anonymizeStmt->execute([$userId]);
        
        // 提交交易
        $pdo->commit();
        
        $response = [
            'success' => true,
            'message' => 'Account deleted successfully',
            'data' => [
                'deleted_at' => date('Y-m-d H:i:s'),
                'reason' => $reason
            ]
        ];
        
        echo json_encode($response);
        
    } catch (Exception $e) {
        // 回滾交易
        $pdo->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
