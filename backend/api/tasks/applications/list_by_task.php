<?php
require_once '../../../config/database.php';
require_once '../../../utils/Response.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    $db = Database::getInstance();

    $taskId = isset($_GET['task_id']) ? trim($_GET['task_id']) : '';
    if ($taskId === '') {
        Response::validationError(['task_id' => 'task_id is required']);
    }

    $limit = (int)($_GET['limit'] ?? 50);
    $offset = (int)($_GET['offset'] ?? 0);

    $sql = "
      SELECT
        ta.id          AS application_id,
        ta.user_id,
        ta.status      AS application_status,
        ta.cover_letter,
        ta.answers_json,
        ta.created_at,
        ta.updated_at,

        u.name         AS applier_name,
        u.avatar_url   AS applier_avatar,

        t.id           AS task_id,
        t.creator_id,
        t.acceptor_id,
        s.code         AS task_status_code,
        s.display_name AS task_status_display
      FROM task_applications ta
      JOIN tasks t ON t.id = ta.task_id
      LEFT JOIN task_statuses s ON s.id = t.status_id
      LEFT JOIN users u ON u.id = ta.user_id
      WHERE ta.task_id = ?
      ORDER BY ta.created_at DESC
      LIMIT ? OFFSET ?
    ";

    $rows = $db->fetchAll($sql, [$taskId, $limit, $offset]);

    Response::success([
      'task_id' => $taskId,
      'applications' => $rows,
      'pagination' => [ 'limit' => $limit, 'offset' => $offset ]
    ], 'Applications by task retrieved');
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>

