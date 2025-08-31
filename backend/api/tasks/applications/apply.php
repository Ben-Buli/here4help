<?php
/**
 * 任務應徵 API
 * POST /backend/api/tasks/applications/apply.php
 * 
 * 接收應徵資料並儲存到 task_applications 表
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../utils/Response.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        Response::error('Method not allowed', 405);
    }

    // 解析請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        Response::error('Invalid JSON input', 400);
    }

    // 驗證必填欄位
    $taskId = $input['task_id'] ?? '';
    $userId = $input['user_id'] ?? 0;
    $coverLetter = $input['cover_letter'] ?? '';

    if (empty($taskId)) {
        Response::validationError(['task_id' => 'task_id is required']);
    }

    if (empty($userId) || !is_numeric($userId)) {
        Response::validationError(['user_id' => 'user_id is required and must be numeric']);
    }

    if (empty($coverLetter)) {
        Response::validationError(['cover_letter' => 'cover_letter is required']);
    }

    // 處理應徵問題答案
    $answers = $input['answers'] ?? [];
    $answersJson = null;
    
    if (!empty($answers) && is_array($answers)) {
        // 清理空值答案
        $cleanAnswers = [];
        foreach ($answers as $question => $answer) {
            $question = trim((string)$question);
            $answer = trim((string)$answer);
            if (!empty($question) && !empty($answer)) {
                $cleanAnswers[$question] = $answer;
            }
        }
        
        if (!empty($cleanAnswers)) {
            $answersJson = json_encode($cleanAnswers, JSON_UNESCAPED_UNICODE);
        }
    }

    $db = Database::getInstance();

    // 檢查任務是否存在
    $task = $db->fetch("SELECT id, creator_id FROM tasks WHERE id = ? LIMIT 1", [$taskId]);
    if (!$task) {
        Response::error('Task not found', 404);
    }

    // 檢查是否為自己的任務
    if ((int)$task['creator_id'] === (int)$userId) {
        Response::error('Cannot apply to your own task', 400);
    }

    // 檢查是否已經應徵過
    $existingApplication = $db->fetch(
        "SELECT id, status FROM task_applications WHERE task_id = ? AND user_id = ? LIMIT 1",
        [$taskId, $userId]
    );

    if ($existingApplication) {
        // 更新現有應徵
        $db->query(
            "UPDATE task_applications 
             SET status = 'applied', cover_letter = ?, answers_json = ?, updated_at = NOW() 
             WHERE task_id = ? AND user_id = ?",
            [$coverLetter, $answersJson, $taskId, $userId]
        );
        
        $applicationId = $existingApplication['id'];
    } else {
        // 創建新應徵
        $db->query(
            "INSERT INTO task_applications (task_id, user_id, status, cover_letter, answers_json, created_at, updated_at) 
             VALUES (?, ?, 'applied', ?, ?, NOW(), NOW())",
            [$taskId, $userId, $coverLetter, $answersJson]
        );
        
        $applicationId = $db->lastInsertId();
    }

    // 獲取完整的應徵資料
    $application = $db->fetch(
        "SELECT 
            ta.*,
            u.name AS user_name,
            u.email AS user_email,
            u.avatar_url AS user_avatar,
            t.title AS task_title,
            t.creator_id
         FROM task_applications ta 
         JOIN users u ON u.id = ta.user_id 
         JOIN tasks t ON t.id = ta.task_id
         WHERE ta.id = ?",
        [$applicationId]
    );

    Response::success([
        'application_id' => (int)$applicationId,
        'task_id' => $taskId,
        'user_id' => (int)$userId,
        'status' => 'applied',
        'cover_letter' => $coverLetter,
        'answers' => $answers,
        'application' => $application,
        'created_at' => $application['created_at'] ?? null,
        'updated_at' => $application['updated_at'] ?? null,
    ], 'Application submitted successfully');

} catch (Exception $e) {
    error_log('[apply.php] Error: ' . $e->getMessage());
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>
