<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../config/php84_compatibility.php';

/**
 * 更新任務 API
 * PUT /api/tasks/update.php?id={taskId}
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/socket_notifier.php';

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
    // 身份驗證 - 獲取操作者ID
    $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
    $actorId = null;
    if (!empty($auth_header) && preg_match('/Bearer\s+(.*)$/i', $auth_header, $m)) {
        $actorId = TokenValidator::validateAuthHeader($auth_header);
        if ($actorId) {
            $actorId = (int)$actorId;
        }
    }
    
    $db = Database::getInstance();

    // 允許更新的欄位
    $updatable = [
        'title', 'description', 'reward_point', 'location', 'task_date', 'language_requirement',
        'hashtags', 'creator_id', 'participant_id', 'status_id', 'status_code'
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
                case 'participant_id':
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

    // 如果狀態更新為 pending_confirmation (status_id = 3)，同步更新 task_applications.status
    if ($statusId !== null && $statusId == 3) {
        // 獲取 pending_confirmation 狀態的 code 來確認
        $statusCodeRow = $db->fetch("SELECT code FROM task_statuses WHERE id = ?", [$statusId]);
        if ($statusCodeRow && $statusCodeRow['code'] === 'pending_confirmation') {
            // 更新該任務的所有 accepted 應徵狀態為 pending
            $db->query(
                "UPDATE task_applications SET status = 'pending', updated_at = NOW() 
                 WHERE task_id = ? AND status = 'accepted'",
                [$taskId]
            );
            
            // 插入系統訊息到聊天室
            try {
                $room = $db->fetch(
                    "SELECT id FROM chat_rooms WHERE task_id = ? ORDER BY id DESC LIMIT 1",
                    [$taskId]
                );
                if ($room && isset($room['id'])) {
                    $content = 'Task marked as completed and is now pending confirmation.';
                    // 修正：系統訊息應該使用系統帳號 ID (1)，而不是操作者 ID
                    $systemUserId = 1; // 固定使用系統帳號
                    $db->query(
                        "INSERT INTO chat_messages (room_id, from_user_id, content, kind, created_at) VALUES (?, ?, ?, 'system', NOW())",
                        [(int)$room['id'], $systemUserId, $content]
                    );
                    
                    // 獲取插入的訊息ID
                    $messageId = $db->lastInsertId();
                }
            } catch (Exception $e) {
                error_log("Failed to insert system message: " . $e->getMessage());
            }
            
            // 發送 Socket 通知 - 任務狀態更新為 pending_confirmation
            try {
                $socketNotifier = SocketNotifier::getInstance();
                $userIds = $socketNotifier->getTaskUserIds($taskId);
                $room = $db->fetch(
                    "SELECT id FROM chat_rooms WHERE task_id = ? ORDER BY id DESC LIMIT 1",
                    [$taskId]
                );
                $roomId = $room ? $room['id'] : null;
                
                $statusData = [
                    'code' => 'pending_confirmation',
                    'display_name' => 'Pending Confirmation',
                    'progress_ratio' => 0.8
                ];
                
                $socketNotifier->notifyTaskStatusUpdate($taskId, $roomId, $statusData, $userIds);
                
                // 發送新訊息通知（如果有插入系統訊息）
                if (isset($messageId) && $messageId && $roomId) {
                    $systemUserId = 1; // 固定使用系統帳號 ID
                    $socketNotifier->notifyNewMessage($roomId, $messageId, $content, $systemUserId, 'system', $userIds);
                }
            } catch (Exception $e) {
                error_log("Socket notification failed: " . $e->getMessage());
            }
        }
    }

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

