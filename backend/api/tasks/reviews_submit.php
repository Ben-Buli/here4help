<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::methodNotAllowed('Only POST method is allowed');
}

try {
    // 驗證 JWT - 使用標準的 $_SERVER 方式，支持 MAMP
    $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
    $token = $_GET['token'] ?? $_POST['token'] ?? null;
    
    if (!$token && !empty($auth_header) && preg_match('/Bearer\s+(.*)$/i', $auth_header, $matches)) {
        $token = $matches[1];
    }
    
    if (!$token) {
        Response::unauthorized('No token provided');
    }
    
    $userData = JWTManager::validateToken($token);
    
    if (!$userData) {
        Response::unauthorized('Invalid token');
    }
    
    $raterId = (int)($userData['user_id'] ?? $userData['id'] ?? 0);
    
    // 解析請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        Response::badRequest('Invalid JSON input');
    }
    
    $taskId = $input['task_id'];
    $taskerId = $input['tasker_id'];
    $rating = (int)($input['rating']);
    $comment = $input['comment'];
    
    // 驗證必要欄位
    if (empty($taskId)) {
        Response::badRequest('Task ID is required');
    }
    
    if (empty($taskerId)) {
        Response::badRequest('Tasker ID is required');
    }
    
    if ($rating < 1 || $rating > 5) {
        Response::badRequest('Rating must be between 1 and 5');
    }
    
    // 使用統一的資料庫連線
    $db = Database::getInstance();
    
    // 檢查任務是否存在且用戶有權限評價
    $taskCheckSql = "
        SELECT t.id, t.creator_id, t.participant_id, ts.code as status_code
        FROM tasks t
        LEFT JOIN task_statuses ts ON t.status_id = ts.id
        WHERE t.id = ?
    ";
    
    $task = $db->fetch($taskCheckSql, [$taskId]);
    
    if (!$task) {
        Response::badRequest('Task not found');
    }
    
    // 檢查評價權限
    $canRate = false;
    if ($raterId == $task['creator_id'] && $taskerId == $task['participant_id']) {
        // 任務發布者評價接受者
        $canRate = true;
    } elseif ($raterId == $task['participant_id'] && $taskerId == $task['creator_id']) {
        // 任務接受者評價發布者
        $canRate = true;
    }
    
    if (!$canRate) {
        Response::forbidden('You do not have permission to rate this task');
    }
    
    // 檢查任務狀態是否允許評價
    if (!in_array($task['status_code'], ['completed'])) {
        Response::badRequest('Task must be completed or cancelled to submit a review');
    }
    
    // 檢查是否已經評價過
    $existingRating = $db->fetch("
        SELECT id FROM task_ratings 
        WHERE task_id = ? AND rater_id = ? AND tasker_id = ?
    ", [$taskId, $raterId, $taskerId]);
    
    if ($existingRating) {
        Response::badRequest('You have already rated this task');
    }
    
    // 插入評價
    $insertSql = "
        INSERT INTO task_ratings (task_id, rater_id, tasker_id, rating, comment, created_at)
        VALUES (?, ?, ?, ?, ?, NOW())
    ";
    
    $db->query($insertSql, [$taskId, $raterId, $taskerId, $rating, $comment]);
    $ratingId = $db->lastInsertId();
    
    Response::success([
        'rating_id' => (int)$ratingId,
        'task_id' => $taskId,
        'tasker_id' => (int)$taskerId,
        'rating' => $rating,
        'comment' => $comment,
        'submitted_at' => date('Y-m-d H:i:s')
    ], 'Review submitted successfully');
    
} catch (Exception $e) {
    Response::serverError('Submit review failed: ' . $e->getMessage());
}
?>

