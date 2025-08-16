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

        t.id,
        t.title,
        t.description,
        t.location,
        t.reward_point,
        t.status_id,
        t.created_at,
        t.updated_at,
        
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

        -- 簡化 chat_rooms 查詢，只檢查是否存在聊天室
        (SELECT cr.id FROM chat_rooms cr 
         WHERE cr.task_id = t.id 
         AND (cr.creator_id = t.creator_id OR cr.participant_id = ta.user_id)
         LIMIT 1) AS chat_room_id,
        
        -- 獲取最新聊天訊息片段
        COALESCE(
            (SELECT SUBSTRING(cm.content, 1, 100)
             FROM chat_messages cm 
             JOIN chat_rooms cr2 ON cm.room_id = cr2.id
             WHERE cr2.task_id = t.id 
             AND (cr2.creator_id = t.creator_id OR cr2.participant_id = ta.user_id)
             ORDER BY cm.created_at DESC 
             LIMIT 1),
            'No conversation yet'
        ) AS latest_message_snippet
      FROM task_applications ta
      JOIN tasks t ON t.id = ta.task_id
      LEFT JOIN task_statuses s ON s.id = t.status_id
      LEFT JOIN users u ON u.id = t.creator_id
      WHERE ta.user_id = ?
      ORDER BY ta.created_at DESC
      LIMIT ? OFFSET ?
    ";

    $rows = $db->fetchAll($sql, [$userId, $limit, $offset]);
    $taskIds = array_map(fn($r) => $r['id'], $rows);

    // 添加除錯資訊
    error_log("🔍 [My Works API] 查詢用戶 ID: $userId");
    error_log("🔍 [My Works API] 查詢結果數量: " . count($rows));
    error_log("🔍 [My Works API] SQL: $sql");
    error_log("🔍 [My Works API] 參數: " . json_encode([$userId, $limit, $offset]));

    Response::success([
      'applications' => $rows,
      'task_ids' => $taskIds,
      'pagination' => [ 'limit' => $limit, 'offset' => $offset ],
      'debug_info' => [
        'user_id' => $userId,
        'result_count' => count($rows),
        'sql' => $sql,
        'parameters' => [$userId, $limit, $offset]
      ]
    ], 'My applications retrieved');
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>

