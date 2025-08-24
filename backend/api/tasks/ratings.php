<?php
/**
 * POST /api/tasks/{task_id}/ratings
 * 提交任務評分
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
}

try {
    // 驗證JWT Token
    $tokenValidation = JWTManager::validateRequest();
    if (!$tokenValidation['valid']) {
        Response::error($tokenValidation['message'], 401);
    }
    $tokenData = $tokenValidation['payload'];
    $raterId = $tokenData['user_id'];
    
    // 從請求參數或 POST 資料獲取 task_id
    $taskId = $_GET['task_id'] ?? null;
    
    if (!$taskId) {
        Response::error('Task ID is required as query parameter', 400);
    }
    
    // 解析請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        Response::error('Invalid JSON input', 400);
    }
    
    $rating = isset($input['rating']) ? (int)$input['rating'] : null;
    $comment = $input['comment'] ?? '';
    
    // 驗證必要欄位
    if ($rating === null || $rating < 1 || $rating > 5) {
        Response::validationError(['rating' => 'Rating must be an integer between 1 and 5']);
    }
    
    if (empty(trim($comment))) {
        Response::validationError(['comment' => 'Comment is required']);
    }
    
    $db = Database::getInstance();
    
    // 檢查任務是否存在
    $taskQuery = "
        SELECT 
            t.id,
            t.creator_id,
            t.participant_id,
            t.status_id,
            ts.code AS status_code,
            ta.user_id AS accepted_user_id
        FROM tasks t
        JOIN task_statuses ts ON ts.id = t.status_id
        LEFT JOIN task_applications ta ON t.id = ta.task_id AND ta.status = 'accepted'
        WHERE t.id = ?
    ";
    
    $task = $db->fetch($taskQuery, [$taskId]);
    
    if (!$task) {
        Response::error('Task not found', 404);
    }
    
    // 檢查任務狀態是否允許評分
    if ((int)$task['status_id'] !== 5) {
        Response::error('Task must be completed to submit a rating', 403);
    }
    
    // 確定評分權限和被評分者
    $taskerId = null;
    $canRate = false;
    
    if ((int)$raterId === (int)$task['creator_id']) {
        // 任務發布者評分執行者
        if ($task['participant_id']) {
            $taskerId = (int)$task['participant_id'];
            $canRate = true;
        }
    } elseif ($task['accepted_user_id'] && (int)$raterId === (int)$task['accepted_user_id']) {
        // 任務執行者評分發布者
        $taskerId = (int)$task['creator_id'];
        $canRate = true;
    }
    
    if (!$canRate || !$taskerId) {
        Response::error('You do not have permission to rate this task', 403);
    }
    
    // 檢查是否已經評分過
    $existingRating = $db->fetch(
        "SELECT id FROM task_ratings WHERE task_id = ? AND rater_id = ? AND tasker_id = ?",
        [$taskId, $raterId, $taskerId]
    );
    
    if ($existingRating) {
        Response::error('You have already rated this task', 409);
    }
    
    // 開始事務
    $db->beginTransaction();
    
    try {
        // 插入評分
        $insertQuery = "
            INSERT INTO task_ratings (task_id, rater_id, tasker_id, rating, comment, created_at)
            VALUES (?, ?, ?, ?, ?, NOW())
        ";
        
        $db->query($insertQuery, [$taskId, $raterId, $taskerId, $rating, $comment]);
        $ratingId = $db->lastInsertId();
        
        // 獲取插入的評分資料
        $newRating = $db->fetch(
            "SELECT tr.*, u.name AS rater_name, u.avatar_url AS rater_avatar 
             FROM task_ratings tr 
             JOIN users u ON u.id = tr.rater_id 
             WHERE tr.id = ?",
            [$ratingId]
        );
        
        $db->commit();
        
        Response::success([
            'rating_id' => (int)$ratingId,
            'task_id' => $taskId,
            'rating' => (int)$rating,
            'comment' => $comment,
            'rater' => [
                'id' => (int)$raterId,
                'name' => $newRating['rater_name'],
                'avatar_url' => $newRating['rater_avatar'],
                'is_you' => true
            ],
            'created_at' => $newRating['created_at']
        ], 'Rating submitted successfully');
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Rating submission error: " . $e->getMessage());
    Response::error('Failed to submit rating: ' . $e->getMessage(), 500);
}
?>
