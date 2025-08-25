<?php
/**
 * GET /api/account/achievements
 * 獲取用戶成就統計數據
 * - 總積分 (users.points)
 * - 完成任務數 (task_applications with status='accepted' and task completed)
 * - 五星評分數 (user_ratings where tasker_id=user_id and rating=5)
 * - 平均評分 (user_ratings where tasker_id=user_id)
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../auth_helper.php';

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
    
    // 檢查是否查詢特定用戶（可選參數）
    $targetUserId = $_GET['user_id'] ?? $userId;
    
    // 驗證 user_id 參數
    if (!is_numeric($targetUserId)) {
        Response::error('Invalid user_id parameter', 400);
    }
    
    $db = Database::getInstance();
    
    // 1. 獲取用戶基本信息和積分
    $userQuery = "
        SELECT 
            id,
            name,
            email,
            points,
            avatar_url
        FROM users 
        WHERE id = ?
    ";
    
    $user = $db->fetch($userQuery, [$targetUserId]);
    
    if (!$user) {
        Response::error('User not found', 404);
    }
    
    // 2. 獲取完成任務數 - 統計已接受且任務狀態為完成的任務
    $completedTasksQuery = "
        SELECT COUNT(*) as completed_tasks
        FROM task_applications ta
        JOIN tasks t ON t.id = ta.task_id
        JOIN task_statuses ts ON ts.id = t.status_id
        WHERE ta.user_id = ? 
        AND ta.status = 'accepted'
        AND ts.code = 'completed'
    ";
    
    $completedTasksResult = $db->fetch($completedTasksQuery, [$targetUserId]);
    $completedTasks = (int)($completedTasksResult['completed_tasks'] ?? 0);
    
    // 3. 獲取五星評分數
    $fiveStarRatingsQuery = "
        SELECT COUNT(*) as five_star_count
        FROM task_ratings
        WHERE tasker_id = ? AND rating = 5
    ";
    
    $fiveStarResult = $db->fetch($fiveStarRatingsQuery, [$targetUserId]);
    $fiveStarRatings = (int)($fiveStarResult['five_star_count'] ?? 0);
    
    // 4. 獲取平均評分
    $avgRatingQuery = "
        SELECT 
            ROUND(AVG(rating), 1) AS avg_rating,
            COUNT(*) AS total_ratings
        FROM task_ratings
        WHERE tasker_id = ?
    ";
    
    $avgRatingResult = $db->fetch($avgRatingQuery, [$targetUserId]);
    $avgRating = $avgRatingResult['avg_rating'] ? (float)$avgRatingResult['avg_rating'] : 0.0;
    $totalRatings = (int)($avgRatingResult['total_ratings'] ?? 0);
    
    // 5. 獲取額外統計信息
    $additionalStatsQuery = "
        SELECT 
            -- 總申請任務數
            (SELECT COUNT(*) FROM task_applications WHERE user_id = ?) as total_applications,
            
            -- 被接受的申請數
            (SELECT COUNT(*) FROM task_applications WHERE user_id = ? AND status = 'accepted') as accepted_applications,
            
            -- 發布的任務數
            (SELECT COUNT(*) FROM tasks WHERE creator_id = ?) as posted_tasks,
            
            -- 獲得的總評論數
            (SELECT COUNT(*) FROM task_ratings WHERE tasker_id = ? AND comment IS NOT NULL AND comment != '') as total_comments
    ";
    
    $additionalStats = $db->fetch($additionalStatsQuery, [$targetUserId, $targetUserId, $targetUserId, $targetUserId]);
    
    // 格式化響應數據
    $achievements = [
        'user_info' => [
            'id' => (int)$user['id'],
            'name' => $user['name'],
            'email' => $user['email'],
            'avatar_url' => $user['avatar_url']
        ],
        'achievements' => [
            'total_coins' => (int)($user['points'] ?? 0),
            'tasks_completed' => $completedTasks,
            'five_star_ratings' => $fiveStarRatings,
            'avg_rating' => $avgRating
        ],
        'additional_stats' => [
            'total_applications' => (int)($additionalStats['total_applications'] ?? 0),
            'accepted_applications' => (int)($additionalStats['accepted_applications'] ?? 0),
            'posted_tasks' => (int)($additionalStats['posted_tasks'] ?? 0),
            'total_ratings' => $totalRatings,
            'total_comments' => (int)($additionalStats['total_comments'] ?? 0)
        ]
    ];
    
    Response::success($achievements, 'User achievements retrieved successfully');
    
} catch (Exception $e) {
    error_log("User achievements error: " . $e->getMessage());
    Response::error('Failed to retrieve user achievements: ' . $e->getMessage(), 500);
}
?>
