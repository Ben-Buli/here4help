<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

/**
 * POST /api/wallet/withdraw-requests-cancel.php
 * 取消提領申請（僅 pending）
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
}

try {
    $auth = JWTManager::validateRequest();
    if (!$auth['valid']) {
        Response::error($auth['message'], 401);
    }
    $userId = (int)$auth['payload']['user_id'];

    $input = json_decode(file_get_contents('php://input'), true) ?? [];
    $requestId = isset($input['request_id']) ? (int)$input['request_id'] : 0;

    if ($requestId <= 0) {
        Response::validationError(['request_id' => 'Invalid request id']);
    }

    $db = Database::getInstance();
    $request = $db->fetch(
        "SELECT id, user_id, status FROM point_withdraw_requests WHERE id = ?",
        [$requestId]
    );

    if (!$request || (int)$request['user_id'] !== $userId) {
        Response::error('Withdraw request not found', 404);
    }

    if ($request['status'] !== 'pending') {
        Response::error('Only pending requests can be cancelled', 422);
    }

    $db->query(
        "UPDATE point_withdraw_requests
         SET status = 'cancelled', cancelled_at = NOW(), updated_at = NOW()
         WHERE id = ?",
        [$requestId]
    );

    $ip = $_SERVER['REMOTE_ADDR'] ?? null;
    $userAgent = $_SERVER['HTTP_USER_AGENT'] ?? null;
    $db->query(
        "INSERT INTO user_active_log
            (user_id, actor_type, actor_id, action, field, old_value, new_value, reason, ip, user_agent, metadata, created_at)
         VALUES (?, 'user', ?, 'withdraw_cancel', 'withdraw_status', 'pending', 'cancelled', NULL, ?, ?, ?, NOW())",
        [
            $userId,
            $userId,
            $ip,
            $userAgent,
            json_encode([
                'request_id' => $requestId,
            ]),
        ]
    );

    Response::success(['request_id' => $requestId], 'Withdraw request cancelled');
} catch (Exception $e) {
    error_log("Withdraw cancel error: " . $e->getMessage());
    Response::error('Failed to cancel withdraw request: ' . $e->getMessage(), 500);
}
?>
