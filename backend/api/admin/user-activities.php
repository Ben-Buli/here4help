<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

/**
 * 管理員使用者活動紀錄 API
 * 
 * 功能：
 * - 查詢 user_active_log 表的使用者活動紀錄
 * - 支援篩選：user_id, action, actor_type, date_range, search, pagination
 * - 支援排序：created_at, user_id, action
 * - 回傳統計資訊：total_activities, unique_users, unique_actions
 * 
 * 路徑：GET /api/admin/user-activities.php
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// 僅允許 GET 請求
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    // JWT 認證 - 支援 Header 和 URL 參數
    $headers = getallheaders();
    $authHeader = $headers['Authorization'] ?? '';
    $token = null;
    
    if ($authHeader && preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
        $token = $matches[1];
    } elseif (isset($_GET['token'])) {
        $token = $_GET['token'];
    }
    
    if (!$token) {
        Response::error('Missing or invalid authorization header', 401);
    }
    
    $jwtManager = new JWTManager();
    $payload = $jwtManager->validateToken($token);
    
    if (!$payload) {
        Response::error('Invalid or expired token', 401);
    }
    
    // 檢查管理員權限 (假設 permission >= 50 為管理員)
    if (!isset($payload['permission']) || $payload['permission'] < 50) {
        Response::error('Insufficient permissions', 403);
    }
    
    $db = Database::getInstance()->getConnection();
    
    // 獲取查詢參數
    $page = max(1, intval($_GET['page'] ?? 1));
    $perPage = min(100, max(1, intval($_GET['per_page'] ?? 15)));
    $offset = ($page - 1) * $perPage;
    
    // 篩選參數
    $userId = isset($_GET['user_id']) ? intval($_GET['user_id']) : null;
    $action = $_GET['action'] ?? '';
    $actorType = $_GET['actor_type'] ?? '';
    $dateFrom = $_GET['date_from'] ?? '';
    $dateTo = $_GET['date_to'] ?? '';
    $search = $_GET['search'] ?? '';
    $sortBy = $_GET['sort_by'] ?? 'created_at';
    $sortOrder = strtoupper($_GET['sort_order'] ?? 'DESC');
    
    // 驗證排序參數
    $allowedSortFields = ['created_at', 'user_id', 'action', 'actor_type'];
    if (!in_array($sortBy, $allowedSortFields)) {
        $sortBy = 'created_at';
    }
    if (!in_array($sortOrder, ['ASC', 'DESC'])) {
        $sortOrder = 'DESC';
    }
    
    // 構建 WHERE 條件
    $whereConditions = [];
    $params = [];
    
    if ($userId) {
        $whereConditions[] = "ual.user_id = ?";
        $params[] = $userId;
    }
    
    if ($action) {
        $whereConditions[] = "ual.action LIKE ?";
        $params[] = "%{$action}%";
    }
    
    if ($actorType) {
        $whereConditions[] = "ual.actor_type = ?";
        $params[] = $actorType;
    }
    
    if ($dateFrom) {
        $whereConditions[] = "DATE(ual.created_at) >= ?";
        $params[] = $dateFrom;
    }
    
    if ($dateTo) {
        $whereConditions[] = "DATE(ual.created_at) <= ?";
        $params[] = $dateTo;
    }
    
    if ($search) {
        $whereConditions[] = "(u.name LIKE ? OR u.email LIKE ? OR ual.reason LIKE ? OR ual.action LIKE ?)";
        $searchParam = "%{$search}%";
        $params[] = $searchParam;
        $params[] = $searchParam;
        $params[] = $searchParam;
        $params[] = $searchParam;
    }
    
    $whereClause = empty($whereConditions) ? '' : 'WHERE ' . implode(' AND ', $whereConditions);
    
    // 獲取總數
    $countSql = "
        SELECT COUNT(*) as total
        FROM user_active_log ual
        LEFT JOIN users u ON ual.user_id = u.id
        {$whereClause}
    ";
    
    $countStmt = $db->prepare($countSql);
    $countStmt->execute($params);
    $totalCount = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    $lastPage = ceil($totalCount / $perPage);
    
    // 獲取統計資訊
    $statsSql = "
        SELECT 
            COUNT(*) as total_activities,
            COUNT(DISTINCT ual.user_id) as unique_users,
            COUNT(DISTINCT ual.action) as unique_actions
        FROM user_active_log ual
        LEFT JOIN users u ON ual.user_id = u.id
        {$whereClause}
    ";
    
    $statsStmt = $db->prepare($statsSql);
    $statsStmt->execute($params);
    $stats = $statsStmt->fetch(PDO::FETCH_ASSOC);
    
    // 獲取活動紀錄列表
    $listSql = "
        SELECT 
            ual.id,
            ual.user_id,
            ual.actor_type,
            ual.actor_id,
            ual.action,
            ual.field,
            ual.old_value,
            ual.new_value,
            ual.reason,
            ual.ip,
            ual.user_agent,
            ual.request_id,
            ual.trace_id,
            ual.metadata,
            ual.created_at,
            u.name as user_name,
            u.email as user_email,
            CASE 
                WHEN ual.actor_type = 'admin' THEN 
                    COALESCE(a.username, CONCAT('Admin ', ual.actor_id))
                WHEN ual.actor_type = 'user' THEN 
                    COALESCE(actor_user.name, CONCAT('User ', ual.actor_id))
                ELSE 'System'
            END as actor_name,
            CASE 
                WHEN ual.actor_type = 'admin' THEN a.username
                ELSE NULL
            END as admin_username,
            CASE 
                WHEN ual.actor_type = 'admin' THEN CONCAT(a.username)
                ELSE NULL
            END as admin_full_name
        FROM user_active_log ual
        LEFT JOIN users u ON ual.user_id = u.id
        LEFT JOIN admins a ON ual.actor_type = 'admin' AND ual.actor_id = a.id
        LEFT JOIN users actor_user ON ual.actor_type = 'user' AND ual.actor_id = actor_user.id
        {$whereClause}
        ORDER BY ual.{$sortBy} {$sortOrder}
        LIMIT {$perPage} OFFSET {$offset}
    ";
    
    $listStmt = $db->prepare($listSql);
    $listStmt->execute($params);
    $activities = $listStmt->fetchAll(PDO::FETCH_ASSOC);
    
    // 處理 JSON metadata
    foreach ($activities as &$activity) {
        if ($activity['metadata']) {
            $activity['metadata'] = json_decode($activity['metadata'], true);
        }
        
        // 格式化數值
        $activity['id'] = (int)$activity['id'];
        $activity['user_id'] = (int)$activity['user_id'];
        $activity['actor_id'] = $activity['actor_id'] ? (int)$activity['actor_id'] : null;
    }
    
    // 計算分頁資訊
    $from = $totalCount > 0 ? $offset + 1 : 0;
    $to = min($offset + $perPage, $totalCount);
    
    // 回傳結果
    Response::success([
        'items' => $activities,
        'pagination' => [
            'current_page' => $page,
            'per_page' => $perPage,
            'total' => (int)$totalCount,
            'last_page' => (int)$lastPage,
            'from' => $from,
            'to' => $to
        ],
        'stats' => [
            'total_activities' => (int)$stats['total_activities'],
            'unique_users' => (int)$stats['unique_users'],
            'unique_actions' => (int)$stats['unique_actions']
        ],
        'filters' => [
            'user_id' => $userId,
            'action' => $action,
            'actor_type' => $actorType,
            'date_from' => $dateFrom,
            'date_to' => $dateTo,
            'search' => $search,
            'sort_by' => $sortBy,
            'sort_order' => strtolower($sortOrder)
        ]
    ]);
    
} catch (Exception $e) {
    error_log("User Activities API Error: " . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}
