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

    // 首先檢查任務是否存在
    $taskCheck = $db->fetch("SELECT id, title FROM tasks WHERE id = ?", [$taskId]);
    if (!$taskCheck) {
        Response::error("Task not found: $taskId", 404);
    }

    // 檢查表是否存在
    try {
        $db->query("SELECT 1 FROM task_applications LIMIT 1");
    } catch (Exception $e) {
        Response::error('Table task_applications does not exist: ' . $e->getMessage(), 500);
    }

    try {
        $db->query("SELECT 1 FROM task_statuses LIMIT 1");
    } catch (Exception $e) {
        Response::error('Table task_statuses does not exist: ' . $e->getMessage(), 500);
    }

    try {
        $db->query("SELECT 1 FROM users LIMIT 1");
    } catch (Exception $e) {
        Response::error('Table users does not exist: ' . $e->getMessage(), 500);
    }

    // 根據規格文件更新的 SQL 查詢
    // - 使用 participant_id 而不是 participant_id
    // - 確保 status 欄位使用正確的 ENUM 值
    $sql = "
      SELECT
        ta.id                           AS application_id,
        ta.user_id,
        ta.status                       AS application_status,
        ta.cover_letter,
        ta.created_at,
        ta.updated_at,
        u.name                          AS applier_name,
        u.avatar_url                    AS applier_avatar,
        t.id                            AS task_id,
        t.creator_id,
        t.participant_id,               -- 根據規格：acceptor_id → participant_id
        ts.code                         AS task_status_code,
        ts.display_name                 AS task_status_display,
        -- 是否為被錄用者（依文件 2.1 的 accepted_flag 生成欄位）
        (ta.status = 'accepted')        AS is_accepted,
        -- 申請問題與回答（可選，彙整為 JSON）
        aq.questions_json
      FROM task_applications AS ta
      JOIN tasks AS t
        ON t.id = ta.task_id
      LEFT JOIN task_statuses AS ts
        ON ts.id = t.status_id
      LEFT JOIN users AS u
        ON u.id = ta.user_id
      LEFT JOIN (
        SELECT
          q.task_id,
          JSON_ARRAYAGG(
            JSON_OBJECT(
              'id', q.id,
              'question', q.application_question,
              'reply', q.applier_reply
            )
          ) AS questions_json
        FROM application_questions AS q
        GROUP BY q.task_id
      ) AS aq
        ON aq.task_id = ta.task_id
      WHERE t.id = ?
      ORDER BY ta.created_at DESC
      LIMIT ? OFFSET ?
    ";

    $rows = $db->fetchAll($sql, [$taskId, $limit, $offset]);

    Response::success([
      'task_id' => $taskId,
      'applications' => $rows,
      'pagination' => [ 'limit' => $limit, 'offset' => $offset ],
      'database_schema' => 'updated_to_participant_id' // 標記已更新到新架構
    ], 'Applications by task retrieved');
    
} catch (Exception $e) {
    // 記錄錯誤到日誌
    error_log("list_by_task.php error: " . $e->getMessage() . " in " . $e->getFile() . " on line " . $e->getLine());
    
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>

