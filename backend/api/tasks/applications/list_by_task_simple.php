<?php
/**
 * 簡化版本的 list_by_task.php
 * 用於測試基本的數據庫查詢
 */

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

    // 簡化查詢：只查詢應徵表，不做複雜的 JOIN
    $sql = "
      SELECT
        ta.id          AS application_id,
        ta.user_id,
        ta.status      AS application_status,
        ta.cover_letter,
        ta.answers_json,
        ta.created_at,
        ta.updated_at
      FROM task_applications ta
      WHERE ta.task_id = ?
      ORDER BY ta.created_at DESC
    ";

    $rows = $db->fetchAll($sql, [$taskId]);

    Response::success([
      'task_id' => $taskId,
      'applications' => $rows,
      'count' => count($rows)
    ], 'Applications by task retrieved (simplified)');
    
} catch (Exception $e) {
    error_log("list_by_task_simple.php error: " . $e->getMessage());
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>
