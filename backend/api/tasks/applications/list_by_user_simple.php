<?php
/**
 * 最簡化版本的 list_by_user.php
 * 用於測試基本功能
 */

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../utils/Response.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    $db = Database::getInstance();

    // 參數驗證
    $userId = isset($_GET['user_id']) ? (int)$_GET['user_id'] : 0;
    if ($userId <= 0) {
        Response::validationError(['user_id' => 'user_id is required and must be positive']);
    }

    $limit = (int)($_GET['limit'] ?? 50);
    $offset = (int)($_GET['offset'] ?? 0);

    // 最簡化的查詢 - 只查詢必要的欄位
    $sql = "
      SELECT
        ta.id                AS application_id,
        ta.status            AS application_status,
        ta.cover_letter,
        ta.created_at,
        ta.updated_at,
        t.id                 AS task_id,
        t.title,
        t.description,
        t.location,
        t.reward_point,
        u.name               AS creator_name,
        u.avatar_url         AS creator_avatar
      FROM task_applications ta
      JOIN tasks t ON t.id = ta.task_id
      LEFT JOIN users u ON u.id = t.creator_id
      WHERE ta.user_id = ?
      ORDER BY ta.created_at DESC
      LIMIT ? OFFSET ?
    ";

    $rows = $db->fetchAll($sql, [$userId, $limit, $offset]);
    
    if (!is_array($rows)) {
        $rows = [];
    }

    Response::success([
      'applications' => $rows,
      'count' => count($rows),
      'pagination' => [ 'limit' => $limit, 'offset' => $offset ],
      'debug_info' => [
        'user_id' => $userId,
        'result_count' => count($rows)
      ]
    ], 'My applications retrieved (simplified)');

} catch (Throwable $e) {
    error_log("list_by_user_simple.php error: " . $e->getMessage());
    
    Response::success([
      'applications' => [],
      'count' => 0,
      'pagination' => [ 'limit' => $limit ?? 50, 'offset' => $offset ?? 0 ],
      'error' => 'db_error',
      'message' => $e->getMessage()
    ], 'Error occurred while retrieving applications');
}
?>
