<?php
/**
 * GET /api/ratings/posted
 * 獲取用戶發布的任務列表（發布者視角）
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    // 驗證JWT Token
    $tokenValidation = JWTManager::validateRequest();
    if (!$tokenValidation['valid']) {
        Response::error($tokenValidation['message'], 401);
    }
    $tokenData = $tokenValidation['payload'];
    $userId = $tokenData['user_id'];
    
    $db = Database::getInstance();
    
    // 獲取查詢參數
    $page = max(1, (int)($_GET['page'] ?? 1));
    $perPage = min(50, max(10, (int)($_GET['per_page'] ?? 20)));
    
    $offset = ($page - 1) * $perPage;
    
    // 獲取總記錄數
    $countQuery = "
        SELECT COUNT(*) as total 
        FROM tasks t 
        WHERE t.creator_id = ? AND t.status_id NOT IN (6, 7,8)
    ";
    $totalResult = $db->fetch($countQuery, [$userId]);
    $total = (int)$totalResult['total'];
    
    // 獲取任務列表
    $tasksQuery = "
        SELECT 
            t.id,
            t.title,
            t.task_date,
            t.reward_point,
            t.status_id,
            ts.display_name AS status_name,
            t.participant_id,
            ROUND(AVG(tr.rating)) AS avg_rating_for_participant,
            EXISTS(
                SELECT 1 FROM task_ratings tr2 
                WHERE tr2.task_id = t.id AND tr2.rater_id = t.creator_id
            ) AS creator_already_rated,
            (
                SELECT JSON_OBJECT(
                    'rating', tr3.rating,
                    'comment', tr3.comment,
                    'rater_id', tr3.rater_id,
                    'created_at', tr3.created_at
                )
                FROM task_ratings tr3 
                WHERE tr3.task_id = t.id AND tr3.rater_id = t.creator_id
                LIMIT 1
            ) AS creator_rating_data
        FROM tasks t
        JOIN task_statuses ts ON ts.id = t.status_id
        LEFT JOIN task_ratings tr ON tr.task_id = t.id AND tr.tasker_id = t.participant_id
        WHERE t.creator_id = ? AND t.status_id NOT IN (6, 7,8)
        GROUP BY t.id, t.title, t.task_date, t.reward_point, t.status_id, ts.display_name, t.participant_id
        ORDER BY t.task_date DESC, t.id DESC
        LIMIT ? OFFSET ?
    ";
    
    $tasks = $db->fetchAll($tasksQuery, [$userId, $perPage, $offset]);
    
    // 格式化任務列表
    $formattedTasks = array_map(function($task) use ($userId) {
        $ratingData = null;
        if ($task['creator_rating_data']) {
            $ratingJson = json_decode($task['creator_rating_data'], true);
            if ($ratingJson) {
                $ratingData = [
                    'rating' => (int)$ratingJson['rating'],
                    'comment' => $ratingJson['comment'],
                    'rater' => [
                        'id' => (int)$ratingJson['rater_id'],
                        'name' => 'You', // 因為是自己評分
                        'avatar_url' => null,
                        'is_you' => true
                    ],
                    'created_at' => $ratingJson['created_at']
                ];
            }
        }
        
        return [
            'task_id' => $task['id'],
            'title' => $task['title'],
            'task_date' => $task['task_date'],
            'reward_point' => $task['reward_point'],
            'status_id' => (int)$task['status_id'],
            'status_name' => $task['status_name'],
            'participant_id' => $task['participant_id'] ? (int)$task['participant_id'] : null,
            'avg_rating_for_participant' => $task['avg_rating_for_participant'] ? (int)$task['avg_rating_for_participant'] : null,
            'has_rating_from_creator' => (bool)$task['creator_already_rated'],
            'creator_rating' => $ratingData,
            'can_rate' => (int)$task['status_id'] === 5 && $task['participant_id'] && !$task['creator_already_rated']
        ];
    }, $tasks);
    
    // 計算分頁資訊
    $totalPages = ceil($total / $perPage);
    $hasNextPage = $page < $totalPages;
    $hasPrevPage = $page > 1;
    
    Response::success([
        'items' => $formattedTasks,
        'pagination' => [
            'current_page' => $page,
            'per_page' => $perPage,
            'total' => $total,
            'total_pages' => $totalPages,
            'has_next_page' => $hasNextPage,
            'has_prev_page' => $hasPrevPage
        ]
    ], 'Posted tasks retrieved successfully');
    
} catch (Exception $e) {
    error_log("Posted tasks error: " . $e->getMessage());
    Response::error('Failed to retrieve posted tasks: ' . $e->getMessage(), 500);
}
?>
