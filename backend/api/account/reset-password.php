<?php
require_once __DIR__ . '/bootstrap.php';
// 載入 PHP 8.4 相容性配置

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
    
    // 解析請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }
    
    $token = $input['token'] ?? '';
    $email = trim($input['email'] ?? '');
    $newPassword = $input['new_password'] ?? '';
    $confirmPassword = $input['confirm_password'] ?? '';
    
    // 驗證必要欄位
    if (empty($token)) {
        throw new Exception('Reset token is required');
    }
    
    if (empty($email)) {
        throw new Exception('Email is required');
    }
    
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        throw new Exception('Invalid email format');
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
    
    // 密碼強度檢查（對齊 Flutter App 使用者註冊規則）
    if (strlen($newPassword) < 6) {
        throw new Exception('Password must be at least 6 characters long');
    }
    
    if (!preg_match('/^[A-Za-z0-9]+$/', $newPassword)) {
        throw new Exception('Password can only contain letters and numbers');
    }
    
    // 建立資料庫連線
    $pdo = new PDO("mysql:host=" . EnvLoader::get('DB_HOST') . ";dbname=" . EnvLoader::get('DB_NAME'), 
                   EnvLoader::get('DB_USERNAME'), EnvLoader::get('DB_PASSWORD'));
    
    // 驗證重設 token
    $stmt = $pdo->prepare("
        SELECT evt.user_id, evt.created_at, evt.created_by, evt.created_by_name, u.email 
        FROM email_verification_tokens evt
        JOIN users u ON evt.user_id = u.id
        WHERE evt.token = ? AND u.email = ? AND evt.type = 'password_reset' 
        AND evt.expires_at > NOW() AND evt.used = 0
    ");
    $stmt->execute([$token, $email]);
    $resetRecord = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$resetRecord) {
        throw new Exception('Invalid or expired reset token');
    }
    
    // 查詢用戶
    $userStmt = $pdo->prepare("SELECT id, password, permission FROM users WHERE email = ?");
    $userStmt->execute([$email]);
    $user = $userStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user || PermissionHelper::isDeleted($user['permission'] ?? 0)) {
        throw new Exception('User not found');
    }
    
    // 檢查新密碼是否與當前密碼相同
    if (password_verify($newPassword, $user['password'])) {
        throw new Exception('New password must be different from current password');
    }
    
    // 開始資料庫交易
    $pdo->beginTransaction();
    
    try {
        // 更新密碼
        $hashedNewPassword = password_hash($newPassword, PASSWORD_DEFAULT);
        
        $updateStmt = $pdo->prepare("
            UPDATE users 
            SET password = ?, updated_at = NOW() 
            WHERE id = ?
        ");
        
        $updateStmt->execute([$hashedNewPassword, $user['id']]);
        
        // 標記重設 token 為已使用
        $markUsedStmt = $pdo->prepare("
            UPDATE email_verification_tokens 
            SET used = 1, used_at = NOW() 
            WHERE token = ? AND type = 'password_reset'
        ");
        $markUsedStmt->execute([$token]);
        
        // 記錄操作日誌
        $logSql = "
            INSERT INTO user_activity_logs (user_id, action, details, ip_address, created_at)
            VALUES (?, 'password_reset_completed', ?, ?, NOW())
        ";
        
        $logStmt = $pdo->prepare($logSql);
        $logStmt->execute([
            $user['id'], 
            json_encode([
                'email' => $email,
                'reset_token_created_at' => $resetRecord['created_at'],
                'reset_requested_by_admin_id' => $resetRecord['created_by'] ?? null,
                'reset_requested_by_admin_name' => $resetRecord['created_by_name'] ?? null,
                'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? 'unknown'
            ]),
            $_SERVER['REMOTE_ADDR'] ?? 'unknown'
        ]);

        try {
            $metadata = [
                'email' => $email,
                'reset_token_created_at' => $resetRecord['created_at'],
                'reset_requested_by_admin_id' => $resetRecord['created_by'] ?? null,
                'reset_requested_by_admin_name' => $resetRecord['created_by_name'] ?? null,
            ];

            $reason = $resetRecord['created_by']
                ? sprintf(
                    'Reset link issued by admin %s (#%s)',
                    $resetRecord['created_by_name'] ?? 'unknown',
                    $resetRecord['created_by']
                )
                : 'Self-service password reset';

            UserActiveLogger::logAction(
                $pdo,
                (int)$user['id'],
                'password_reset_completed',
                'password',
                null,
                'updated',
                $reason,
                'user',
                (int)$user['id'],
                null,
                null,
                $metadata
            );
        } catch (Exception $logError) {
            // swallow logging errors
        }
        
        // 提交交易
        $pdo->commit();
        
        $response = [
            'success' => true,
            'message' => 'Password reset successfully',
            'data' => [
                'email' => $email,
                'reset_at' => date('Y-m-d H:i:s')
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
