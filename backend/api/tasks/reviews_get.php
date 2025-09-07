<?php
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::methodNotAllowed('Only GET method is allowed');
}

try {
    // 驗證 JWT - 支持 MAMP 兼容性
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
    
    $userId = (int)($userData['user_id'] ?? $userData['id'] ?? 0);
    
    $task_id = isset($_GET['task_id']) ? (string)$_GET['task_id'] : '';
    if ($task_id === '') {
        Response::badRequest('Task ID is required');
    }

    $db = Database::getInstance();
    
    // 檢查任務是否存在且用戶有權限查看評分
    $task = $db->fetch("
        SELECT t.id, t.creator_id, t.participant_id, ts.code as status_code
        FROM tasks t
        LEFT JOIN task_statuses ts ON t.status_id = ts.id
        WHERE t.id = ?
    ", [$task_id]);
    
    if (!$task) {
        Response::badRequest('Task not found');
    }
    
    // 檢查用戶權限：只有任務創建者或參與者可以查看評分
    if ($userId != $task['creator_id'] && $userId != $task['participant_id']) {
        Response::forbidden('You do not have permission to view this review');
    }
    
    // 獲取評分記錄
    $rating = $db->fetch("
        SELECT tr.*, u.name as rater_name, u2.name as tasker_name
        FROM task_ratings tr
        LEFT JOIN users u ON tr.rater_id = u.id
        LEFT JOIN users u2 ON tr.tasker_id = u2.id
        WHERE tr.task_id = ?
    ", [$task_id]);
    
    if (!$rating) {
        Response::success(null, 'No review found');
    }
    
    Response::success([
        'rating_id' => (int)$rating['id'],
        'task_id' => $rating['task_id'],
        'rater_id' => (int)$rating['rater_id'],
        'rater_name' => $rating['rater_name'],
        'tasker_id' => (int)$rating['tasker_id'],
        'tasker_name' => $rating['tasker_name'],
        'rating' => (int)$rating['rating'],
        'comment' => $rating['comment'],
        'created_at' => $rating['created_at'],
    ], 'Review retrieved successfully');
    
} catch (Exception $e) {
    Response::serverError('Get review failed: ' . $e->getMessage());
}
?>

