<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../utils/Response.php';
require_once __DIR__ . '/../../../utils/TokenValidator.php';
require_once __DIR__ . '/../../../utils/socket_notifier.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
}

try {
    error_log("[reject.php] 🔍 Request started");
    
    // 驗證 Authorization token
    $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
    error_log("[reject.php] 🔍 Auth header: " . (empty($auth_header) ? 'empty' : 'found'));
    
    if (empty($auth_header)) {
        error_log("[reject.php] ❌ Authorization header missing");
        Response::error('Authorization header required', 401);
    }
    
    $actor_id = TokenValidator::validateAuthHeader($auth_header);
    error_log("[reject.php] 🔍 Token validation result: " . ($actor_id ? 'success' : 'failed'));
    
    if (!$actor_id) {
        error_log("[reject.php] ❌ Invalid or expired token");
        Response::error('Invalid or expired token', 401);
    }
    $actor_id = (int)$actor_id;
    error_log("[reject.php] 🔍 Actor ID: $actor_id");

    $db = Database::getInstance();
    $conn = $db->getConnection();

    $raw = file_get_contents('php://input');
    error_log("[reject.php] 🔍 Raw input: " . $raw);
    
    $body = json_decode($raw, true);
    if (!is_array($body)) { 
        $body = $_POST; 
        error_log("[reject.php] 🔍 Using $_POST data: " . json_encode($_POST));
    } else {
        error_log("[reject.php] 🔍 JSON decoded body: " . json_encode($body));
    }

    $taskId = isset($body['task_id']) ? trim($body['task_id']) : '';
    $userId = isset($body['user_id']) ? (int)$body['user_id'] : 0;
    $posterId = isset($body['poster_id']) ? (int)$body['poster_id'] : 0;

    error_log("[reject.php] 🔍 Parsed parameters:");
    error_log("[reject.php]   - taskId: '$taskId'");
    error_log("[reject.php]   - userId: $userId");
    error_log("[reject.php]   - posterId: $posterId");

    if ($taskId === '' || $userId <= 0 || $posterId <= 0) {
        error_log("[reject.php] ❌ Validation failed - missing required parameters");
        Response::validationError([
            'task_id' => 'task_id is required',
            'user_id' => 'user_id is required (applier to reject)',
            'poster_id' => 'poster_id is required (must be task creator)'
        ]);
    }
    
    // 驗證操作者權限：必須是任務創建者
    error_log("[reject.php] 🔍 Checking permissions: actor_id=$actor_id, posterId=$posterId");
    if ($actor_id !== $posterId) {
        error_log("[reject.php] ❌ Permission denied: actor is not task creator");
        Response::error('Only task creator can reject applications', 403);
    }

    // 開始交易
    error_log("[reject.php] 🔍 Starting transaction");
    $conn->beginTransaction();

    try {
        // 1. 驗證任務歸屬
        error_log("[reject.php] 🔍 Verifying task ownership");
        $task = $db->fetch("SELECT id, creator_id FROM tasks WHERE id = ?", [$taskId]);
        error_log("[reject.php] 🔍 Task query result: " . json_encode($task));
        
        if (!$task) {
            error_log("[reject.php] ❌ Task not found: $taskId");
            throw new Exception('Task not found');
        }
        if ((int)$task['creator_id'] !== $posterId) {
            error_log("[reject.php] ❌ Creator mismatch: task creator=" . $task['creator_id'] . ", posterId=$posterId");
            throw new Exception('Only task creator can reject applications');
        }

        // 2. 檢查應徵存在且為 applied 狀態
        error_log("[reject.php] 🔍 Checking application status");
        $application = $db->fetch("SELECT id, status FROM task_applications WHERE task_id = ? AND user_id = ?", [$taskId, $userId]);
        error_log("[reject.php] 🔍 Application query result: " . json_encode($application));
        
        if (!$application) {
            error_log("[reject.php] ❌ Application not found: taskId=$taskId, userId=$userId");
            throw new Exception('Application not found');
        }
        if ($application['status'] !== 'applied') {
            error_log("[reject.php] ❌ Application status invalid: " . $application['status']);
            throw new Exception('Application is not in applied status');
        }


        // 3. 標記該應徵為 rejected
        error_log("[reject.php] 🔍 Updating application status to rejected");
        $stmt = $conn->prepare("UPDATE task_applications SET status = 'rejected', updated_at = NOW() WHERE task_id = ? AND user_id = ?");
        $result = $stmt->execute([$taskId, $userId]);
        error_log("[reject.php] 🔍 Update result: " . ($result ? 'success' : 'failed'));
        error_log("[reject.php] 🔍 Affected rows: " . $stmt->rowCount());

        // 3.1 紀錄 user_active_log
        $ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? ($_SERVER['REMOTE_ADDR'] ?? null);
        $metadata = json_encode([
            'task_id' => $taskId,
            'application_user_id' => $userId,
            'application_status_from' => 'applied',
            'application_status_to' => 'rejected',
        ]);
        // 使用較短的 action 字符串以避免數據庫長度限制
        $shortAction = "app_rejected:p{$posterId}_u{$userId}";
        error_log("[reject.php] 🔍 Action string: '$shortAction' (length: " . strlen($shortAction) . ")");
        
        $logStmt = $conn->prepare("INSERT INTO user_active_log (
            user_id, actor_type, actor_id, action, field, old_value, new_value,
            reason, metadata, ip, created_at
          ) VALUES (
            ?, 'user', ?, ?, 'status', 'applied', 'rejected',
            NULL, ?, ?, NOW()
          )");
        $logStmt->execute([$userId, $posterId, $shortAction, $metadata, $ip]);

        error_log("[reject.php] 🔍 Committing transaction");
        $conn->commit();
        error_log("[reject.php] ✅ Transaction committed successfully");

        // 發送 Socket 通知
        try {
            error_log("[reject.php] 🔍 Sending socket notification");
            $socketNotifier = SocketNotifier::getInstance();
            $userIds = $socketNotifier->getTaskUserIds($taskId);
            $room = $db->fetch(
                "SELECT id FROM chat_rooms WHERE task_id = ? ORDER BY id DESC LIMIT 1",
                [$taskId]
            );
            $roomId = $room ? $room['id'] : null;
            
            $socketNotifier->notifyApplicationStatusUpdate($taskId, $roomId, 'rejected', $userIds);
            error_log("[reject.php] ✅ Socket notification sent successfully");
        } catch (Exception $e) {
            error_log("[reject.php] ⚠️ Socket notification failed: " . $e->getMessage());
        }

        // 回傳更新後的應徵紀錄
        error_log("[reject.php] 🔍 Fetching updated application record");
        $updatedApplication = $db->fetch("
            SELECT ta.*, u.name AS user_name
            FROM task_applications ta
            JOIN users u ON u.id = ta.user_id
            WHERE ta.task_id = ? AND ta.user_id = ?", [$taskId, $userId]);

        error_log("[reject.php] ✅ Reject operation completed successfully");
        Response::success($updatedApplication, 'Application rejected successfully');
    } catch (Exception $e) {
        error_log("[reject.php] ❌ Transaction error: " . $e->getMessage());
        $conn->rollback();
        throw $e;
    }
} catch (Exception $e) {
    error_log("[reject.php] ❌ Server error: " . $e->getMessage());
    error_log("[reject.php] ❌ Stack trace: " . $e->getTraceAsString());
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>