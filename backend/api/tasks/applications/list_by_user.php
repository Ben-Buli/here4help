<?php
require_once '../../../config/database.php';
require_once '../../../utils/Response.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    $db = Database::getInstance();

    $userId = isset($_GET['user_id']) ? (int)$_GET['user_id'] : 0;
    if ($userId <= 0) {
        Response::validationError(['user_id' => 'user_id is required']);
    }

    $limit = (int)($_GET['limit'] ?? 50);
    $offset = (int)($_GET['offset'] ?? 0);

    $sql = "
      SELECT
        ta.id                AS application_id,
        ta.status            AS application_status,
        ta.created_at        AS application_created_at,
        ta.updated_at        AS application_updated_at,

        t.*,
        s.code               AS status_code,
        s.display_name       AS status_display,

        CASE WHEN t.acceptor_id IS NOT NULL AND t.acceptor_id <> ta.user_id
             THEN 'rejected_tasker'
             ELSE s.code
        END AS client_status_code,

        CASE WHEN t.acceptor_id IS NOT NULL AND t.acceptor_id <> ta.user_id
             THEN 'Rejected (Tasker)'
             ELSE s.display_name
        END AS client_status_display,

        u.id                 AS creator_id,
        u.name               AS creator_name,
        u.avatar_url         AS creator_avatar,

        cr.id                AS chat_room_id,
        
        -- 獲取最新聊天訊息片段
        COALESCE(
            (SELECT SUBSTRING(cm.message, 1, 100)
             FROM chat_messages cm 
             WHERE cm.room_id = cr.id 
             ORDER BY cm.created_at DESC 
             LIMIT 1),
            'No conversation yet'
        ) AS latest_message_snippet
      FROM task_applications ta
      JOIN tasks t ON t.id = ta.task_id
      LEFT JOIN task_statuses s ON s.id = t.status_id
      LEFT JOIN users u ON u.id = t.creator_id
      LEFT JOIN chat_rooms cr ON cr.task_id = t.id AND cr.creator_id = t.creator_id AND cr.participant_id = ta.user_id
      WHERE ta.user_id = ?
      ORDER BY ta.created_at DESC
      LIMIT ? OFFSET ?
    ";

    $rows = $db->fetchAll($sql, [$userId, $limit, $offset]);
    $taskIds = array_map(fn($r) => $r['id'], $rows);

    Response::success([
      'applications' => $rows,
      'task_ids' => $taskIds,
      'pagination' => [ 'limit' => $limit, 'offset' => $offset ]
    ], 'My applications retrieved');
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>

