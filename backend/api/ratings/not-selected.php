<?php
/**
 * GET /api/ratings/not-selected
 * 獲取用戶未被選中的申請列表（應徵者視角）
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
        FROM task_applications a
        JOIN tasks t ON t.id = a.task_id
        WHERE a.user_id = ? AND a.status IN ('rejected','cancelled','withdrawn')
    ";
    $totalResult = $db->fetch($countQuery, [$userId]);
    $total = (int)$totalResult['total'];
    
    // 獲取申請列表
    $applicationsQuery = "
        SELECT 
            a.id AS application_id,
            t.id AS task_id,
            t.title,
            t.task_date,
            t.reward_point,
            t.description,
            t.location,
            a.status AS application_status,
            a.created_at AS applied_at,
            a.updated_at AS status_updated_at,
            u.name AS creator_name,
            u.avatar_url AS creator_avatar
        FROM task_applications a
        JOIN tasks t ON t.id = a.task_id
        JOIN users u ON u.id = t.creator_id
        WHERE a.user_id = ? AND a.status IN ('rejected','cancelled','withdrawn')
        ORDER BY a.created_at DESC, a.id DESC
        LIMIT ? OFFSET ?
    ";
    
    $applications = $db->fetchAll($applicationsQuery, [$userId, $perPage, $offset]);
    
    // 格式化申請列表
    $formattedApplications = array_map(function($app) {
        // 狀態顯示名稱映射
        $statusDisplayMap = [
            'rejected' => 'Rejected',
            'cancelled' => 'Cancelled', 
            'withdrawn' => 'Withdrawn'
        ];
        
        // 狀態顏色映射
        $statusColorMap = [
            'rejected' => 'red',
            'cancelled' => 'grey',
            'withdrawn' => 'blue'
        ];
        
        return [
            'application_id' => (int)$app['application_id'],
            'task_id' => $app['task_id'],
            'title' => $app['title'],
            'task_date' => $app['task_date'],
            'reward_point' => $app['reward_point'],
            'description' => $app['description'],
            'location' => $app['location'],
            'application_status' => $app['application_status'],
            'application_status_display' => $statusDisplayMap[$app['application_status']] ?? ucfirst($app['application_status']),
            'application_status_color' => $statusColorMap[$app['application_status']] ?? 'grey',
            'applied_at' => $app['applied_at'],
            'status_updated_at' => $app['status_updated_at'],
            'creator' => [
                'name' => $app['creator_name'],
                'avatar_url' => $app['creator_avatar']
            ]
        ];
    }, $applications);
    
    // 計算分頁資訊
    $totalPages = ceil($total / $perPage);
    $hasNextPage = $page < $totalPages;
    $hasPrevPage = $page > 1;
    
    // 統計各狀態數量
    $statsQuery = "
        SELECT 
            a.status,
            COUNT(*) as count
        FROM task_applications a
        JOIN tasks t ON t.id = a.task_id
        WHERE a.user_id = ? AND a.status IN ('rejected','cancelled','withdrawn')
        GROUP BY a.status
    ";
    
    $stats = $db->fetchAll($statsQuery, [$userId]);
    $formattedStats = [];
    foreach ($stats as $stat) {
        $formattedStats[$stat['status']] = [
            'count' => (int)$stat['count'],
            'display_name' => $statusDisplayMap[$stat['status']] ?? ucfirst($stat['status'])
        ];
    }
    
    Response::success([
        'items' => $formattedApplications,
        'pagination' => [
            'current_page' => $page,
            'per_page' => $perPage,
            'total' => $total,
            'total_pages' => $totalPages,
            'has_next_page' => $hasNextPage,
            'has_prev_page' => $hasPrevPage
        ],
        'statistics' => $formattedStats
    ], 'Not selected applications retrieved successfully');
    
} catch (Exception $e) {
    error_log("Not selected applications error: " . $e->getMessage());
    Response::error('Failed to retrieve not selected applications: ' . $e->getMessage(), 500);
}
?>
