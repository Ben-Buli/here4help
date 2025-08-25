<?php
/**
 * GET /api/ratings/user-stats
 * 獲取使用者評分統計數據
 * 包含平均評分、總評論數、總被評論數
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
    
    // 獲取用戶作為 tasker（被評分者）的統計數據
    $taskerStatsQuery = "
        SELECT 
            tasker_id,
            ROUND(AVG(rating), 1) AS avg_rating,
            COUNT(CASE WHEN comment IS NOT NULL AND comment != '' THEN 1 END) AS total_comments,
            COUNT(*) AS total_reviews
        FROM task_ratings
        WHERE tasker_id = ?
        GROUP BY tasker_id
    ";
    
    $taskerStats = $db->fetch($taskerStatsQuery, [$targetUserId]);
    
    // 獲取用戶作為 rater（評分者）的統計數據
    $raterStatsQuery = "
        SELECT 
            rater_id,
            COUNT(CASE WHEN comment IS NOT NULL AND comment != '' THEN 1 END) AS given_comments,
            COUNT(*) AS given_reviews
        FROM task_ratings
        WHERE rater_id = ?
        GROUP BY rater_id
    ";
    
    $raterStats = $db->fetch($raterStatsQuery, [$targetUserId]);
    
    // 獲取最近的評論（最多5條）
    $recentRatingsQuery = "
        SELECT 
            tr.rating,
            tr.comment,
            tr.created_at,
            u.name AS rater_name,
            u.avatar_url AS rater_avatar,
            t.title AS task_title
        FROM task_ratings tr
        JOIN users u ON u.id = tr.rater_id
        LEFT JOIN tasks t ON t.id = tr.task_id
        WHERE tr.tasker_id = ? AND tr.comment IS NOT NULL AND tr.comment != ''
        ORDER BY tr.created_at DESC
        LIMIT 5
    ";
    
    $recentRatings = $db->fetchAll($recentRatingsQuery, [$targetUserId]);
    
    // 獲取評分分布統計
    $ratingDistributionQuery = "
        SELECT 
            rating,
            COUNT(*) AS count
        FROM task_ratings
        WHERE tasker_id = ?
        GROUP BY rating
        ORDER BY rating DESC
    ";
    
    $ratingDistribution = $db->fetchAll($ratingDistributionQuery, [$targetUserId]);
    
    // 格式化響應數據
    $response = [
        'user_id' => (int)$targetUserId,
        'as_tasker' => [
            'avg_rating' => $taskerStats ? (float)$taskerStats['avg_rating'] : 0.0,
            'total_reviews' => $taskerStats ? (int)$taskerStats['total_reviews'] : 0,
            'total_comments' => $taskerStats ? (int)$taskerStats['total_comments'] : 0,
            'rating_distribution' => array_reduce($ratingDistribution, function($carry, $item) {
                $carry[(int)$item['rating']] = (int)$item['count'];
                return $carry;
            }, [5 => 0, 4 => 0, 3 => 0, 2 => 0, 1 => 0])
        ],
        'as_rater' => [
            'given_reviews' => $raterStats ? (int)$raterStats['given_reviews'] : 0,
            'given_comments' => $raterStats ? (int)$raterStats['given_comments'] : 0
        ],
        'recent_ratings' => array_map(function($rating) {
            return [
                'rating' => (int)$rating['rating'],
                'comment' => $rating['comment'],
                'created_at' => $rating['created_at'],
                'rater' => [
                    'name' => $rating['rater_name'],
                    'avatar_url' => $rating['rater_avatar']
                ],
                'task_title' => $rating['task_title']
            ];
        }, $recentRatings)
    ];
    
    Response::success($response, 'User rating statistics retrieved successfully');
    
} catch (Exception $e) {
    error_log("User rating stats error: " . $e->getMessage());
    Response::error('Failed to retrieve user rating statistics: ' . $e->getMessage(), 500);
}
?>
