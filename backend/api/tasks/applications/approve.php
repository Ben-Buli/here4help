<?php
require_once '../../../config/database.php';
require_once '../../../utils/Response.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
}

try {
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
            'user_id' => 'user_id is required (applier to approve)',
            'poster_id' => 'poster_id is required (must be task creator)'
        ]);
    }

    // 開始交易
    $conn->beginTransaction();

    try {
        // 1. 驗證任務歸屬與狀態
        $task = $db->fetch("SELECT id, creator_id, acceptor_id, status_id FROM tasks WHERE id = ?", [$taskId]);
        if (!$task) {
            throw new Exception('Task not found');
        }
        if ((int)$task['creator_id'] !== $posterId) {
            throw new Exception('Only task creator can approve applications');
        }
        if ($task['acceptor_id'] !== null) {
            throw new Exception('Task already has an assigned tasker');
        }

        // 2. 檢查應徵存在且為 applied 狀態
        $application = $db->fetch("SELECT id, status FROM task_applications WHERE task_id = ? AND user_id = ?", [$taskId, $userId]);
        if (!$application) {
            throw new Exception('Application not found');
        }
        if ($application['status'] !== 'applied') {
            throw new Exception('Application is not in applied status');
        }

        // 3. 指派任務執行者
        $stmt = $conn->prepare("UPDATE tasks SET acceptor_id = ?, status_id = (SELECT id FROM task_statuses WHERE code = 'in_progress' LIMIT 1), updated_at = NOW() WHERE id = ?");
        $stmt->execute([$userId, $taskId]);

        // 4. 標記該應徵為 accepted
        $stmt = $conn->prepare("UPDATE task_applications SET status = 'accepted', updated_at = NOW() WHERE task_id = ? AND user_id = ?");
        $stmt->execute([$taskId, $userId]);

        // 5. 標記其他應徵為 rejected
        $stmt = $conn->prepare("UPDATE task_applications SET status = 'rejected', updated_at = NOW() WHERE task_id = ? AND user_id != ?");
        $stmt->execute([$taskId, $userId]);

        $conn->commit();

        // 回傳更新後的任務資訊
        $updatedTask = $db->fetch("
            SELECT t.*, s.code AS status_code, s.display_name AS status_display,
                   u.name AS acceptor_name
            FROM tasks t
            LEFT JOIN task_statuses s ON t.status_id = s.id
            LEFT JOIN users u ON t.acceptor_id = u.id
            WHERE t.id = ?", [$taskId]);

        Response::success($updatedTask, 'Application approved successfully');
    } catch (Exception $e) {
        $conn->rollback();
        throw $e;
    }
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>