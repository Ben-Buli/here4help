<?php
/**
 * 聚合API：獲取用戶發布的任務及其應徵者
 * 單一API調用替代多次查詢，大幅提升性能
 */

require_once '../../config/database.php';
require_once '../../utils/Response.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    $db = Database::getInstance();
    
    // 獲取用戶ID
    $userId = isset($_GET['user_id']) ? (int)$_GET['user_id'] : 0;
    if ($userId <= 0) {
        Response::validationError(['user_id' => 'user_id is required']);
    }

    $limit = (int)($_GET['limit'] ?? 20);
    $offset = (int)($_GET['offset'] ?? 0);

    // 一次性查詢：獲取用戶發布的任務
    $tasksSql = "
        SELECT 
            t.*,
            s.code AS status_code,
            s.display_name AS status_display,
            s.progress_ratio,
            s.sort_order,
            u.name AS creator_name,
            u.avatar_url AS creator_avatar
        FROM tasks t
        LEFT JOIN task_statuses s ON t.status_id = s.id
        LEFT JOIN users u ON t.creator_id = u.id
        WHERE t.creator_id = ?
        ORDER BY t.created_at DESC
        LIMIT ? OFFSET ?
    ";
    
    $tasks = $db->fetchAll($tasksSql, [$userId, $limit, $offset]);
    $taskIds = array_column($tasks, 'id');

    if (empty($taskIds)) {
        Response::success([
            'tasks_with_applicants' => [],
            'pagination' => ['limit' => $limit, 'offset' => $offset, 'total' => 0]
        ], 'No posted tasks found');
        return;
    }

    // 一次性查詢：獲取所有任務的應徵者（避免N+1查詢）
    $placeholders = str_repeat('?,', count($taskIds) - 1) . '?';
    $applicantsSql = "
        SELECT
            ta.id AS application_id,
            ta.task_id,
            ta.user_id,
            ta.status AS application_status,
            ta.cover_letter,
            ta.answers_json,
            ta.created_at,
            ta.updated_at,
            u.name AS applier_name,
            u.avatar_url AS applier_avatar,
            -- 預載入聊天室信息
            cr.id AS room_id,
            cr.type AS room_type
        FROM task_applications ta
        LEFT JOIN users u ON u.id = ta.user_id
        LEFT JOIN chat_rooms cr ON (cr.task_id = ta.task_id AND cr.participant_id = ta.user_id)
        WHERE ta.task_id IN ($placeholders)
        ORDER BY ta.task_id, ta.created_at DESC
    ";
    
    $applicants = $db->fetchAll($applicantsSql, $taskIds);

    // 一次性查詢：獲取所有任務的問題
    $questionsSql = "
        SELECT task_id, application_question, id
        FROM application_questions
        WHERE task_id IN ($placeholders)
        ORDER BY task_id, created_at
    ";
    
    $questions = $db->fetchAll($questionsSql, $taskIds);

    // 組織數據結構
    $applicantsByTask = [];
    foreach ($applicants as $applicant) {
        $taskId = $applicant['task_id'];
        if (!isset($applicantsByTask[$taskId])) {
            $applicantsByTask[$taskId] = [];
        }
        $applicantsByTask[$taskId][] = $applicant;
    }

    $questionsByTask = [];
    foreach ($questions as $question) {
        $taskId = $question['task_id'];
        if (!isset($questionsByTask[$taskId])) {
            $questionsByTask[$taskId] = [];
        }
        $questionsByTask[$taskId][] = $question;
    }

    // 合併數據
    $tasksWithApplicants = [];
    foreach ($tasks as $task) {
        $taskId = $task['id'];
        
        // 處理 hashtags
        $task['hashtags'] = $task['hashtags'] ? explode(',', $task['hashtags']) : [];
        
        // 添加應徵者數據
        $task['applicants'] = $applicantsByTask[$taskId] ?? [];
        $task['applicants_count'] = count($task['applicants']);
        
        // 添加問題數據
        $task['application_questions'] = $questionsByTask[$taskId] ?? [];
        
        $tasksWithApplicants[] = $task;
    }

    // 獲取總數
    $countSql = "SELECT COUNT(*) as total FROM tasks WHERE creator_id = ?";
    $totalResult = $db->fetch($countSql, [$userId]);
    $total = $totalResult['total'];

    Response::success([
        'tasks_with_applicants' => $tasksWithApplicants,
        'pagination' => [
            'total' => $total,
            'limit' => $limit,
            'offset' => $offset,
            'has_more' => ($offset + $limit) < $total
        ]
    ], 'Posted tasks with applicants retrieved');

} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>
/**
 * 聚合API：獲取用戶發布的任務及其應徵者
 * 單一API調用替代多次查詢，大幅提升性能
 */

require_once '../../config/database.php';
require_once '../../utils/Response.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    $db = Database::getInstance();
    
    // 獲取用戶ID
    $userId = isset($_GET['user_id']) ? (int)$_GET['user_id'] : 0;
    if ($userId <= 0) {
        Response::validationError(['user_id' => 'user_id is required']);
    }

    $limit = (int)($_GET['limit'] ?? 20);
    $offset = (int)($_GET['offset'] ?? 0);

    // 一次性查詢：獲取用戶發布的任務
    $tasksSql = "
        SELECT 
            t.*,
            s.code AS status_code,
            s.display_name AS status_display,
            s.progress_ratio,
            s.sort_order,
            u.name AS creator_name,
            u.avatar_url AS creator_avatar
        FROM tasks t
        LEFT JOIN task_statuses s ON t.status_id = s.id
        LEFT JOIN users u ON t.creator_id = u.id
        WHERE t.creator_id = ?
        ORDER BY t.created_at DESC
        LIMIT ? OFFSET ?
    ";
    
    $tasks = $db->fetchAll($tasksSql, [$userId, $limit, $offset]);
    $taskIds = array_column($tasks, 'id');

    if (empty($taskIds)) {
        Response::success([
            'tasks_with_applicants' => [],
            'pagination' => ['limit' => $limit, 'offset' => $offset, 'total' => 0]
        ], 'No posted tasks found');
        return;
    }

    // 一次性查詢：獲取所有任務的應徵者（避免N+1查詢）
    $placeholders = str_repeat('?,', count($taskIds) - 1) . '?';
    $applicantsSql = "
        SELECT
            ta.id AS application_id,
            ta.task_id,
            ta.user_id,
            ta.status AS application_status,
            ta.cover_letter,
            ta.answers_json,
            ta.created_at,
            ta.updated_at,
            u.name AS applier_name,
            u.avatar_url AS applier_avatar,
            -- 預載入聊天室信息
            cr.id AS room_id,
            cr.type AS room_type
        FROM task_applications ta
        LEFT JOIN users u ON u.id = ta.user_id
        LEFT JOIN chat_rooms cr ON (cr.task_id = ta.task_id AND cr.participant_id = ta.user_id)
        WHERE ta.task_id IN ($placeholders)
        ORDER BY ta.task_id, ta.created_at DESC
    ";
    
    $applicants = $db->fetchAll($applicantsSql, $taskIds);

    // 一次性查詢：獲取所有任務的問題
    $questionsSql = "
        SELECT task_id, application_question, id
        FROM application_questions
        WHERE task_id IN ($placeholders)
        ORDER BY task_id, created_at
    ";
    
    $questions = $db->fetchAll($questionsSql, $taskIds);

    // 組織數據結構
    $applicantsByTask = [];
    foreach ($applicants as $applicant) {
        $taskId = $applicant['task_id'];
        if (!isset($applicantsByTask[$taskId])) {
            $applicantsByTask[$taskId] = [];
        }
        $applicantsByTask[$taskId][] = $applicant;
    }

    $questionsByTask = [];
    foreach ($questions as $question) {
        $taskId = $question['task_id'];
        if (!isset($questionsByTask[$taskId])) {
            $questionsByTask[$taskId] = [];
        }
        $questionsByTask[$taskId][] = $question;
    }

    // 合併數據
    $tasksWithApplicants = [];
    foreach ($tasks as $task) {
        $taskId = $task['id'];
        
        // 處理 hashtags
        $task['hashtags'] = $task['hashtags'] ? explode(',', $task['hashtags']) : [];
        
        // 添加應徵者數據
        $task['applicants'] = $applicantsByTask[$taskId] ?? [];
        $task['applicants_count'] = count($task['applicants']);
        
        // 添加問題數據
        $task['application_questions'] = $questionsByTask[$taskId] ?? [];
        
        $tasksWithApplicants[] = $task;
    }

    // 獲取總數
    $countSql = "SELECT COUNT(*) as total FROM tasks WHERE creator_id = ?";
    $totalResult = $db->fetch($countSql, [$userId]);
    $total = $totalResult['total'];

    Response::success([
        'tasks_with_applicants' => $tasksWithApplicants,
        'pagination' => [
            'total' => $total,
            'limit' => $limit,
            'offset' => $offset,
            'has_more' => ($offset + $limit) < $total
        ]
    ], 'Posted tasks with applicants retrieved');

} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>