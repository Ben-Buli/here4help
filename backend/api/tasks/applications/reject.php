<?php
require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../utils/Response.php';
require_once __DIR__ . '/../../../utils/TokenValidator.php';
require_once __DIR__ . '/../../../utils/socket_notifier.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
}

try {
    // 驗證 Authorization token
    $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
    if (empty($auth_header)) {
        Response::error('Authorization header required', 401);
    }
    
    $actor_id = TokenValidator::validateAuthHeader($auth_header);
    if (!$actor_id) {
        Response::error('Invalid or expired token', 401);
    }
    $actor_id = (int)$actor_id;

    $db = Database::getInstance();
    $conn = $db->getConnection();

    $raw = file_get_contents('php://input');
    $body = json_decode($raw, true);
    if (!is_array($body)) { $body = $_POST; }

    $taskId = isset($body['task_id']) ? trim($body['task_id']) : '';
    $userId = isset($body['user_id']) ? (int)$body['user_id'] : 0;
    $posterId = isset($body['poster_id']) ? (int)$body['poster_id'] : 0;

    if ($taskId === '' || $userId <= 0 || $posterId <= 0) {
        Response::validationError([
            'task_id' => 'task_id is required',
            'user_id' => 'user_id is required (applier to reject)',
            'poster_id' => 'poster_id is required (must be task creator)'
        ]);
    }
    
    // 驗證操作者權限：必須是任務創建者
    if ($actor_id !== $posterId) {
        Response::error('Only task creator can reject applications', 403);
    }

    // 開始交易
    $conn->beginTransaction();

    try {
        // 1. 驗證任務歸屬
        $task = $db->fetch("SELECT id, creator_id FROM tasks WHERE id = ?", [$taskId]);
        if (!$task) {
            throw new Exception('Task not found');
        }
        if ((int)$task['creator_id'] !== $posterId) {
            throw new Exception('Only task creator can reject applications');
        }

        // 2. 檢查應徵存在且為 applied 狀態
        $application = $db->fetch("SELECT id, status FROM task_applications WHERE task_id = ? AND user_id = ?", [$taskId, $userId]);
        if (!$application) {
            throw new Exception('Application not found');
        }
        if ($application['status'] !== 'applied') {
            throw new Exception('Application is not in applied status');
        }


        // 3. 標記該應徵為 rejected
        $stmt = $conn->prepare("UPDATE task_applications SET status = 'rejected', updated_at = NOW() WHERE task_id = ? AND user_id = ?");
        $stmt->execute([$taskId, $userId]);

        // 3.1 紀錄 user_active_log
        $ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? ($_SERVER['REMOTE_ADDR'] ?? null);
        $metadata = json_encode([
            'task_id' => $taskId,
            'application_user_id' => $userId,
            'application_status_from' => 'applied',
            'application_status_to' => 'rejected',
        ]);
        $logStmt = $conn->prepare("INSERT INTO user_active_log (
            user_id, actor_type, actor_id, action, field, old_value, new_value,
            reason, metadata, ip, created_at
          ) VALUES (
            ?, 'user', ?, CONCAT('application_rejected:poster_', ?, '_rejected_user_', ?, '_task_', ?), 'status', 'applied', 'rejected',
            NULL, ?, ?, NOW()
          )");
        $logStmt->execute([$userId, $posterId, $posterId, $userId, $taskId, $metadata, $ip]);

        $conn->commit();

        // 發送 Socket 通知
        try {
            $socketNotifier = SocketNotifier::getInstance();
            $userIds = $socketNotifier->getTaskUserIds($taskId);
            $room = $db->fetch(
                "SELECT id FROM chat_rooms WHERE task_id = ? ORDER BY id DESC LIMIT 1",
                [$taskId]
            );
            $roomId = $room ? $room['id'] : null;
            
            $socketNotifier->notifyApplicationStatusUpdate($taskId, $roomId, 'rejected', $userIds);
        } catch (Exception $e) {
            error_log("Socket notification failed: " . $e->getMessage());
        }

        // 回傳更新後的應徵紀錄
        $updatedApplication = $db->fetch("
            SELECT ta.*, u.name AS user_name
            FROM task_applications ta
            JOIN users u ON u.id = ta.user_id
            WHERE ta.task_id = ? AND ta.user_id = ?", [$taskId, $userId]);

        Response::success($updatedApplication, 'Application rejected successfully');
    } catch (Exception $e) {
        $conn->rollback();
        throw $e;
    }
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>