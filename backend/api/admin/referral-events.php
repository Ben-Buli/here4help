<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

/**
 * GET /api/admin/referral-events
 * 管理員查看推薦事件列表 API
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    // 驗證JWT Token（需要管理員權限）
    $tokenData = JWTManager::validateRequest();
    if (!$tokenData['valid']) {
        Response::error($tokenData['message'], 401);
    }
    
    // 檢查管理員權限
    $adminId = $tokenData['admin_id'] ?? null;
    if (!$adminId) {
        Response::error('Admin access required', 403);
    }
    
    $db = Database::getInstance()->getConnection();
    
    // 獲取查詢參數
    $page = max(1, (int)($_GET['page'] ?? 1));
    $perPage = min(100, max(10, (int)($_GET['per_page'] ?? 20)));
    $status = $_GET['status'] ?? '';
    $search = trim($_GET['search'] ?? '');
    
    $offset = ($page - 1) * $perPage;
    
    // 構建查詢條件
    $whereConditions = [];
    $params = [];
    
    if (!empty($status) && in_array($status, ['pending', 'completed', 'cancelled'])) {
        $whereConditions[] = "re.status = ?";
        $params[] = $status;
    }
    
    if (!empty($search)) {
        $whereConditions[] = "(referrer.name LIKE ? OR referrer.email LIKE ? OR referee.name LIKE ? OR referee.email LIKE ? OR re.referral_code LIKE ?)";
        $searchTerm = "%{$search}%";
        $params = array_merge($params, [$searchTerm, $searchTerm, $searchTerm, $searchTerm, $searchTerm]);
    }
    
    $whereClause = !empty($whereConditions) ? 'WHERE ' . implode(' AND ', $whereConditions) : '';
    
    // 查詢推薦事件列表
    $sql = "
        SELECT 
            re.*,
            referrer.name as referrer_name,
            referrer.email as referrer_email,
            referee.name as referee_name,
            referee.email as referee_email,
            admin.name as admin_name
        FROM referral_events re
        JOIN users referrer ON re.referrer_id = referrer.id
        JOIN users referee ON re.referee_id = referee.id
        LEFT JOIN admins admin ON re.admin_id = admin.id
        {$whereClause}
        ORDER BY re.created_at DESC
        LIMIT ? OFFSET ?
    ";
    
    $params[] = $perPage;
    $params[] = $offset;
    
    $stmt = $db->prepare($sql);
    $stmt->execute($params);
    $events = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // 查詢總數
    $countSql = "
        SELECT COUNT(*) as total
        FROM referral_events re
        JOIN users referrer ON re.referrer_id = referrer.id
        JOIN users referee ON re.referee_id = referee.id
        {$whereClause}
    ";
    
    $countParams = array_slice($params, 0, -2); // 移除 LIMIT 和 OFFSET 參數
    $countStmt = $db->prepare($countSql);
    $countStmt->execute($countParams);
    $totalCount = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // 查詢統計資料
    $statsStmt = $db->prepare("
        SELECT 
            status,
            COUNT(*) as count,
            COALESCE(SUM(reward_points), 0) as total_points
        FROM referral_events 
        GROUP BY status
    ");
    $statsStmt->execute();
    $statsData = $statsStmt->fetchAll(PDO::FETCH_ASSOC);
    
    $stats = [
        'total' => $totalCount,
        'pending' => 0,
        'completed' => 0,
        'cancelled' => 0,
        'total_points_awarded' => 0
    ];
    
    foreach ($statsData as $stat) {
        $stats[$stat['status']] = (int)$stat['count'];
        if ($stat['status'] === 'completed') {
            $stats['total_points_awarded'] = (int)$stat['total_points'];
        }
    }
    
    // 格式化回應資料
    $formattedEvents = array_map(function($event) {
        return [
            'id' => (int)$event['id'],
            'referrer' => [
                'id' => (int)$event['referrer_id'],
                'name' => $event['referrer_name'],
                'email' => $event['referrer_email']
            ],
            'referee' => [
                'id' => (int)$event['referee_id'],
                'name' => $event['referee_name'],
                'email' => $event['referee_email']
            ],
            'referral_code' => $event['referral_code'],
            'status' => $event['status'],
            'reward_points' => (int)$event['reward_points'],
            'completed_at' => $event['completed_at'],
            'admin_name' => $event['admin_name'],
            'notes' => $event['notes'],
            'created_at' => $event['created_at'],
            'updated_at' => $event['updated_at']
        ];
    }, $events);
    
    $pagination = [
        'current_page' => $page,
        'per_page' => $perPage,
        'total' => $totalCount,
        'last_page' => ceil($totalCount / $perPage)
    ];
    
    Response::success([
        'events' => $formattedEvents,
        'pagination' => $pagination,
        'stats' => $stats
    ], 'Referral events retrieved successfully');
    
} catch (Exception $e) {
    error_log("Admin Referral Events API Error: " . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}
?>
