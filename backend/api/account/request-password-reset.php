<?php
require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../utils/Response.php';

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
    
    $email = trim($input['email'] ?? '');
    
    // 驗證必要欄位
    if (empty($email)) {
        throw new Exception('Email is required');
    }
    
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        throw new Exception('Invalid email format');
    }
    
    // 建立資料庫連線
    $pdo = new PDO("mysql:host=" . EnvLoader::get('DB_HOST') . ";dbname=" . EnvLoader::get('DB_NAME'), 
                   EnvLoader::get('DB_USERNAME'), EnvLoader::get('DB_PASSWORD'));
    
    // 檢查用戶是否存在
    $stmt = $pdo->prepare("SELECT id, name, email FROM users WHERE email = ? AND status != 'deleted'");
    $stmt->execute([$email]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        // 為了安全考量，即使用戶不存在也返回成功訊息
        echo json_encode([
            'success' => true,
            'message' => 'If this email exists in our system, you will receive a password reset link shortly.'
        ]);
        exit;
    }
    
    // 生成重設 token
    $resetToken = bin2hex(random_bytes(32));
    $expiresAt = date('Y-m-d H:i:s', time() + 3600); // 1小時後過期
    
    // 檢查是否已有未過期的重設請求
    $existingStmt = $pdo->prepare("
        SELECT id FROM email_verification_tokens 
        WHERE user_id = ? AND type = 'password_reset' AND expires_at > NOW() AND used = 0
    ");
    $existingStmt->execute([$user['id']]);
    
    if ($existingStmt->fetch()) {
        // 標記舊的重設請求為已使用
        $deleteStmt = $pdo->prepare("
            UPDATE email_verification_tokens 
            SET used = 1, used_at = NOW() 
            WHERE user_id = ? AND type = 'password_reset' AND used = 0
        ");
        $deleteStmt->execute([$user['id']]);
    }
    
    // 儲存重設 token
    $insertStmt = $pdo->prepare("
        INSERT INTO email_verification_tokens (user_id, token, type, expires_at, created_at)
        VALUES (?, ?, 'password_reset', ?, NOW())
    ");
    $insertStmt->execute([$user['id'], $resetToken, $expiresAt]);
    
    // 構建重設連結
    $frontendUrl = EnvLoader::get('FRONTEND_URL') ?: 'http://localhost:3000';
    $resetLink = $frontendUrl . '/reset-password?token=' . $resetToken . '&email=' . urlencode($email);
    
    // 發送郵件（這裡使用簡單的 mail() 函數，生產環境建議使用更可靠的郵件服務）
    $subject = 'Password Reset Request - Here4Help';
    $message = "
        <html>
        <head>
            <title>Password Reset Request</title>
        </head>
        <body>
            <h2>Password Reset Request</h2>
            <p>Hello {$user['name']},</p>
            <p>We received a request to reset your password for your Here4Help account.</p>
            <p>Click the link below to reset your password:</p>
            <p><a href=\"{$resetLink}\" style=\"background-color: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;\">Reset Password</a></p>
            <p>Or copy and paste this link into your browser:</p>
            <p>{$resetLink}</p>
            <p>This link will expire in 1 hour.</p>
            <p>If you didn't request this password reset, please ignore this email.</p>
            <br>
            <p>Best regards,<br>The Here4Help Team</p>
        </body>
        </html>
    ";
    
    $headers = [
        'MIME-Version: 1.0',
        'Content-type: text/html; charset=UTF-8',
        'From: noreply@here4help.com',
        'Reply-To: support@here4help.com',
        'X-Mailer: PHP/' . phpversion()
    ];
    
    $mailSent = mail($email, $subject, $message, implode("\r\n", $headers));
    
    // 記錄操作日誌
    $logSql = "
        INSERT INTO user_activity_logs (user_id, action, details, ip_address, created_at)
        VALUES (?, 'password_reset_requested', ?, ?, NOW())
    ";
    
    $logStmt = $pdo->prepare($logSql);
    $logStmt->execute([
        $user['id'], 
        json_encode([
            'email' => $email,
            'token_expires_at' => $expiresAt,
            'mail_sent' => $mailSent,
            'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? 'unknown'
        ]),
        $_SERVER['REMOTE_ADDR'] ?? 'unknown'
    ]);
    
    $response = [
        'success' => true,
        'message' => 'If this email exists in our system, you will receive a password reset link shortly.',
        'data' => [
            'email' => $email,
            'expires_at' => $expiresAt
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
