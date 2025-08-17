<?php
/**
 * 取得任務編輯所需的完整資料（含 application_questions）
 * GET /api/tasks/task_edit_data.php?id={taskId}
 */

require_once '../../config/database.php';
require_once '../../utils/TokenValidator.php';
require_once '../../utils/Response.php';

// 設定 CORS 標頭
Response::setCorsHeaders();

// 僅允許 GET
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    $db = Database::getInstance();

    $taskId = $_GET['id'] ?? ($_GET['task_id'] ?? null);
    if (!$taskId) {
        Response::error('Missing task id', 400);
    }

    // 取得任務基本資料 + 狀態顯示
    $sql = "SELECT t.*, s.code AS status_code, s.display_name AS status_display
            FROM tasks t
            LEFT JOIN task_statuses s ON t.status_id = s.id
            WHERE t.id = ?";
    $task = $db->fetch($sql, [$taskId]);

    if (!$task) {
        Response::error('Task not found', 404);
    }

    // 取得申請問題（若沒有則回傳空陣列）
    $questionsSql = "SELECT id, application_question, 'text' as question_type, sort_order
                     FROM application_questions WHERE task_id = ? ORDER BY sort_order ASC";
    try {
        $questions = $db->fetchAll($questionsSql, [$taskId]);
    } catch (Exception $e) {
        $questions = [];
    }
    $task['application_questions'] = $questions;

    // hashtags 轉陣列
    if (!empty($task['hashtags'])) {
        $task['hashtags'] = explode(',', $task['hashtags']);
    } else {
        $task['hashtags'] = [];
    }

    Response::success($task, 'Task edit data retrieved successfully');
} catch (Exception $e) {
    Response::serverError('Failed to retrieve task edit data: ' . $e->getMessage());
}
?>


