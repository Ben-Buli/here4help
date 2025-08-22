<?php
/**
 * 創建任務 API
 * POST /api/tasks/create.php
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';
require_once __DIR__ . '/../../utils/Response.php';

// 設定 CORS 標頭
Response::setCorsHeaders();

// 只允許 POST 請求
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
}

// 獲取 POST 資料
$input = json_decode(file_get_contents('php://input'), true);

if (!$input) {
    Response::error('Invalid JSON data');
}

// 驗證必填欄位
$requiredFields = ['title', 'description', 'reward_point', 'location', 'task_date', 'language_requirement', 'creator_id'];
$errors = [];

foreach ($requiredFields as $field) {
    if (empty($input[$field])) {
        $errors[] = "Field '$field' is required";
    }
}

// 特別檢查 creator_id 是否為有效的整數
if (isset($input['creator_id']) && !is_numeric($input['creator_id'])) {
    $errors[] = "Field 'creator_id' must be a valid number";
}

// 記錄接收到的數據以便調試
error_log("Task creation request data: " . json_encode($input));

if (!empty($errors)) {
    Response::validationError($errors);
}

try {
    $db = Database::getInstance();
    
    // 生成 UUID
    $taskId = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
    
    // 處理 hashtags
    $hashtags = '';
    if (!empty($input['hashtags']) && is_array($input['hashtags'])) {
        $hashtags = implode(',', $input['hashtags']);
    }
    
    // 解析狀態：支援 status_id / status_code / status(舊文字)
    $statusId = null;
    $statusText = $input['status'] ?? null; // 舊欄位相容
    if (!empty($input['status_id'])) {
        $statusId = (int)$input['status_id'];
    } elseif (!empty($input['status_code'])) {
        $row = $db->fetch('SELECT id, display_name FROM task_statuses WHERE code = ?', [$input['status_code']]);
        if ($row) {
            $statusId = (int)$row['id'];
            $statusText = $row['display_name'];
        }
    } elseif (!empty($statusText)) {
        $normalized = strtolower(str_replace(' ', '_', $statusText));
        $row = $db->fetch('SELECT id, display_name FROM task_statuses WHERE code = ?', [$normalized]);
        if ($row) {
            $statusId = (int)$row['id'];
            $statusText = $row['display_name'];
        }
    }
    // 預設狀態 open
    if ($statusId === null) {
        $row = $db->fetch("SELECT id, display_name FROM task_statuses WHERE code = 'open' LIMIT 1", []);
        if ($row) {
            $statusId = (int)$row['id'];
            $statusText = $row['display_name'];
        } else {
            $statusText = $statusText ?: 'Open';
        }
    }

    // 建立者/接案者
    $creatorId = !empty($input['creator_id']) ? (int)$input['creator_id'] : null;
    $participantId = !empty($input['participant_id']) ? (int)$input['participant_id'] : null;

    // 插入任務資料（僅以 status_id 表示狀態，不再寫入舊欄位 status）
    $sql = "INSERT INTO tasks (
              id, creator_id, participant_id,
              title, description, reward_point, location, task_date,
              start_datetime, end_datetime,
              status_id, language_requirement, hashtags,
              created_at, updated_at
            ) VALUES (
              ?, ?, ?,
              ?, ?, ?, ?, ?,
              ?, ?,
              ?, ?, ?,
              NOW(), NOW()
            )";
    
    $params = [
        $taskId,
        $creatorId,
        $participantId,
        $input['title'],
        $input['description'],
        $input['reward_point'] ?? $input['salary'] ?? '0', // 支援舊的 salary 欄位
        $input['location'],
        $input['task_date'],
        // 新欄位：若未提供則用資料表預設值
        ($input['start_datetime'] ?? '1970-01-01 00:00:00'),
        ($input['end_datetime'] ?? '1970-01-01 01:00:00'),
        $statusId,
        $input['language_requirement'],
        $hashtags
    ];
    
    $db->query($sql, $params);
    
    // 處理申請問題
    if (!empty($input['application_questions']) && is_array($input['application_questions'])) {
        foreach ($input['application_questions'] as $index => $question) {
            if (!empty($question)) {
                // 生成獨立的 UUID 作為問題 ID
                $questionId = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
                    mt_rand(0, 0xffff), mt_rand(0, 0xffff),
                    mt_rand(0, 0xffff),
                    mt_rand(0, 0x0fff) | 0x4000,
                    mt_rand(0, 0x3fff) | 0x8000,
                    mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
                );
                $questionSql = "INSERT INTO application_questions (id, task_id, application_question, created_at, updated_at) VALUES (?, ?, ?, NOW(), NOW())";
                $db->query($questionSql, [$questionId, $taskId, $question]);
            }
        }
    }
    
    // 獲取創建的任務資料
    $taskSql = "SELECT t.*, s.code AS status_code, s.display_name AS status_display
                FROM tasks t
                LEFT JOIN task_statuses s ON t.status_id = s.id
                WHERE t.id = ?";
    $task = $db->fetch($taskSql, [$taskId]);
    
    // 獲取申請問題
    $questionsSql = "SELECT * FROM application_questions WHERE task_id = ?";
    $questions = $db->fetchAll($questionsSql, [$taskId]);
    $task['application_questions'] = $questions;
    
    // 處理 hashtags
    if ($task['hashtags']) {
        $task['hashtags'] = explode(',', $task['hashtags']);
    } else {
        $task['hashtags'] = [];
    }
    
    Response::success($task, 'Task created successfully', 201);
    
} catch (Exception $e) {
    // 記錄詳細錯誤信息
    error_log("Task creation failed: " . $e->getMessage());
    error_log("Stack trace: " . $e->getTraceAsString());
    error_log("Input data: " . json_encode($input));
    
    Response::serverError('Failed to create task: ' . $e->getMessage());
}
?> 