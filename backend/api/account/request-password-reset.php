<?php
require_once __DIR__ . '/bootstrap.php';
require_once dirname(dirname(__DIR__)) . '/utils/SmtpMailer.php';

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
    $stmt = $pdo->prepare("SELECT id, name, email, permission, password FROM users WHERE email = ?");
    $stmt->execute([$email]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user || PermissionHelper::isDeleted($user['permission'] ?? 0)) {
        // 為了安全考量，即使用戶不存在也返回成功訊息
        echo json_encode([
            'success' => true,
            'message' => 'If this email exists in our system, you will receive a password reset link shortly.'
        ]);
        exit;
    }

    if (empty($user['password'])) {
        // 僅限直接註冊帳戶可使用密碼重設
        echo json_encode([
            'success' => true,
            'message' => 'If this email exists in our system, you will receive a password reset link shortly.'
        ]);
        exit;
    }

    $requestIp = $_SERVER['REMOTE_ADDR'] ?? 'unknown';

    // 1 分鐘內僅允許同一 IP 發送一次
    $rateStmt = $pdo->prepare("
        SELECT created_at FROM user_active_log
        WHERE action = 'password_reset_requested' AND ip = ?
        ORDER BY created_at DESC
        LIMIT 1
    ");
    $rateStmt->execute([$requestIp]);
    $lastRequest = $rateStmt->fetch(PDO::FETCH_ASSOC);

    if ($lastRequest) {
        $lastTimestamp = strtotime($lastRequest['created_at']);
        if ($lastTimestamp && (time() - $lastTimestamp) < 60) {
            echo json_encode([
                'success' => true,
                'message' => 'If this email exists in our system, you will receive a password reset link shortly.'
            ]);
            exit;
        }
    }
    
    // 檢查是否已有未過期的重設請求（仍有效則沿用同一連結）
    $existingStmt = $pdo->prepare("
        SELECT token, expires_at FROM email_verification_tokens 
        WHERE user_id = ? AND type = 'password_reset' AND expires_at > NOW() AND used = 0
        ORDER BY expires_at DESC
        LIMIT 1
    ");
    $existingStmt->execute([$user['id']]);
    $existingToken = $existingStmt->fetch(PDO::FETCH_ASSOC);

    if ($existingToken) {
        $resetToken = $existingToken['token'];
        $expiresAt = $existingToken['expires_at'];
    } else {
        // 生成重設 token
        $resetToken = bin2hex(random_bytes(32));
        $expiresAt = date('Y-m-d H:i:s', time() + 3600); // 1小時後過期

        // 儲存重設 token
        $insertStmt = $pdo->prepare("
        INSERT INTO email_verification_tokens (user_id, token, type, expires_at, created_by, created_by_name, created_at)
        VALUES (?, ?, 'password_reset', ?, ?, ?, NOW())
    ");
    $insertStmt->execute([$user['id'], $resetToken, $expiresAt, null, null]);    }
    
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

    $fromEmail = EnvLoader::get('MAIL_FROM_ADDRESS', EnvLoader::get('MAIL_USERNAME', 'noreply@here4help.com'));
    $fromName = EnvLoader::get('MAIL_FROM_NAME', 'Here4Help');
    $replyTo = EnvLoader::get('MAIL_REPLY_TO', '');

    $smtpResult = SmtpMailer::send($email, $subject, $message, $fromEmail, $fromName, $replyTo);
    $mailSent = $smtpResult['success'];
    $mailError = $smtpResult['error'];
    
    // 記錄操作日誌
    $logSql = "
        INSERT INTO user_active_log (
            user_id,
            actor_type,
            actor_id,
            action,
            metadata,
            ip,
            user_agent,
            created_at
        ) VALUES (?, 'user', ?, 'password_reset_requested', ?, ?, ?, NOW())
    ";
    
    $logStmt = $pdo->prepare($logSql);
    $logStmt->execute([
        $user['id'],
        $user['id'],
        json_encode([
            'email' => $email,
            'token_expires_at' => $expiresAt,
            'mail_sent' => $mailSent,
            'mail_error' => $mailError,
        ]),
        $requestIp,
        $_SERVER['HTTP_USER_AGENT'] ?? 'unknown',
    ]);

    if (!$mailSent) {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Failed to send reset email. Please try again later.'
        ]);
        exit;
    }
    
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
