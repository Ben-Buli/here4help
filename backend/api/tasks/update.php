<?php
/**
 * 更新任務 API
 * PUT /api/tasks/update.php?id={taskId}
 */

require_once '../../config/database.php';
require_once '../../utils/Response.php';

// CORS
Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'PUT' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
}

// 支援 query 或 body 傳 id
$taskId = $_GET['id'] ?? null;
$input = json_decode(file_get_contents('php://input'), true);
if (!$input) { $input = []; }
if (!$taskId) { $taskId = $input['id'] ?? null; }
if (!$taskId) { Response::error('Task id is required', 400); }

try {
    $db = Database::getInstance();

    // 允許更新的欄位
    $updatable = [
        'title', 'description', 'reward_point', 'location', 'task_date', 'language_requirement',
        'hashtags', 'creator_id', 'acceptor_id', 'status_id', 'status_code'
    ];

    $set = [];
    $params = [];

    // 處理 hashtags 陣列
    if (isset($input['hashtags']) && is_array($input['hashtags'])) {
        $input['hashtags'] = implode(',', $input['hashtags']);
    }

    // 狀態解析：status_id > status_code（不再支援舊文字 status 欄位）
    $statusId = null;
    if (isset($input['status_id'])) {
        $statusId = (int)$input['status_id'];
    } elseif (!empty($input['status_code'])) {
        $row = $db->fetch('SELECT id, display_name FROM task_statuses WHERE code = ?', [$input['status_code']]);
        if ($row) { $statusId = (int)$row['id']; }
    }

    foreach ($updatable as $field) {
        if (array_key_exists($field, $input)) {
            switch ($field) {
                case 'status_id':
                case 'creator_id':
                case 'acceptor_id':
                    // 實際設定在下方以確保狀態處理一致
                    break;
                default:
                    if ($field !== 'status_code') {
                        $set[] = "$field = ?";
                        $params[] = $input[$field];
                    }
            }
        }
    }

    if ($statusId !== null) {
        $set[] = 'status_id = ?';
        $params[] = $statusId;
    }

    // timestamp
    $set[] = 'updated_at = NOW()';

    if (empty($set)) {
        Response::error('No valid fields to update', 400);
    }

    $sql = 'UPDATE tasks SET ' . implode(', ', $set) . ' WHERE id = ?';
    $params[] = $taskId;
    $db->query($sql, $params);

    // 回傳最新資料
    $task = $db->fetch(
        "SELECT t.*, s.code AS status_code, s.display_name AS status_display
         FROM tasks t LEFT JOIN task_statuses s ON t.status_id = s.id WHERE t.id = ?",
        [$taskId]
    );

    // hashtags 陣列化
    if (!empty($task['hashtags'])) {
        $task['hashtags'] = explode(',', $task['hashtags']);
    } else {
        $task['hashtags'] = [];
    }

    Response::success($task, 'Task updated successfully');
} catch (Exception $e) {
    Response::serverError('Failed to update task: ' . $e->getMessage());
}
?>

