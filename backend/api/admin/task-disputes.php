<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../config/php84_compatibility.php';

/**
 * 管理員任務爭議列表
 * GET /api/admin/task-disputes.php
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/Pagination.php';

header('Content-Type: application/json');
Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::methodNotAllowed('Only GET method is allowed');
}

try {
    // JWT 認證
    $tokenData = JWTManager::validateRequest();
    if (!$tokenData['valid']) {
        Response::unauthorized($tokenData['message']);
    }

    // 檢查管理員權限
    $adminId = $tokenData['admin_id'] ?? null;
    if (!$adminId) {
        Response::forbidden('Admin access required');
    }
    
    // 資料庫連接
    $db = Database::getInstance()->getConnection();
    
    // 驗證管理員角色
    $adminCheck = $db->prepare("
        SELECT ar.name as role_name 
        FROM admins a
        JOIN admin_roles ar ON a.role_id = ar.id
        WHERE a.id = ?
    ");
    $adminCheck->execute([$adminId]);
    $admin = $adminCheck->fetch(PDO::FETCH_ASSOC);
    
    if (!$admin || !in_array($admin['role_name'], ['admin', 'super_admin'])) {
        Response::forbidden('Insufficient permissions to view disputes');
    }
    
    // 獲取查詢參數
    $page = max(1, intval($_GET['page'] ?? 1));
    $perPage = min(100, max(10, intval($_GET['per_page'] ?? 20)));
    $status = $_GET['status'] ?? null;
    $dateFrom = $_GET['date_from'] ?? null;
    $dateTo = $_GET['date_to'] ?? null;
    $sortBy = $_GET['sort_by'] ?? 'created_at';
    $sortOrder = strtoupper($_GET['sort_order'] ?? 'DESC');
    
    // 驗證排序參數
    $allowedSortFields = ['created_at', 'updated_at', 'status', 'id'];
    if (!in_array($sortBy, $allowedSortFields)) {
        $sortBy = 'created_at';
    }
    
    if (!in_array($sortOrder, ['ASC', 'DESC'])) {
        $sortOrder = 'DESC';
    }
    
    // 構建查詢條件
    $whereConditions = [];
    $params = [];
    
    if ($status) {
        $whereConditions[] = "tde.status = ?";
        $params[] = $status;
    }
    
    if ($dateFrom) {
        $whereConditions[] = "DATE(tde.created_at) >= ?";
        $params[] = $dateFrom;
    }
    
    if ($dateTo) {
        $whereConditions[] = "DATE(tde.created_at) <= ?";
        $params[] = $dateTo;
    }
    
    $whereClause = '';
    if (!empty($whereConditions)) {
        $whereClause = 'WHERE ' . implode(' AND ', $whereConditions);
    }
    
    // 計算總數
    $countQuery = "
        SELECT COUNT(*) as total
        FROM task_dispute_events tde
        JOIN tasks t ON tde.task_id = t.id
        JOIN users u ON tde.user_id = u.id
        {$whereClause}
    ";
    
    $countStmt = $db->prepare($countQuery);
    $countStmt->execute($params);
    $totalCount = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // 計算分頁
    $pagination = new Pagination($totalCount, $page, $perPage);
    $offset = ($page - 1) * $perPage;
    
    // 主查詢
    $query = "
        SELECT 
            tde.id,
            tde.task_id,
            tde.user_id,
            tde.title as dispute_title,
            tde.description,
            tde.status,
            tde.decision_result,
            tde.decision_note,
            tde.admin_id,
            tde.created_at,
            tde.updated_at,
            t.title as task_title,
            t.reward_point,
            t.creator_id,
            t.participant_id,
            u.name as submitter_name,
            u.email as submitter_email,
            creator.name as creator_name,
            participant.name as participant_name,
            admin.username as admin_username
        FROM task_dispute_events tde
        JOIN tasks t ON tde.task_id = t.id
        JOIN users u ON tde.user_id = u.id
        LEFT JOIN users creator ON t.creator_id = creator.id
        LEFT JOIN users participant ON t.participant_id = participant.id
        LEFT JOIN admins admin ON tde.admin_id = admin.id
        {$whereClause}
        ORDER BY tde.{$sortBy} {$sortOrder}
        LIMIT {$perPage} OFFSET {$offset}
    ";
    
    $stmt = $db->prepare($query);
    $stmt->execute($params);
    $disputes = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // 格式化資料
    $formattedDisputes = array_map(function($dispute) {
        return [
            'id' => (int)$dispute['id'],
            'task_id' => $dispute['task_id'],
            'dispute_title' => $dispute['dispute_title'],
            'description' => $dispute['description'],
            'status' => $dispute['status'],
            'decision_result' => $dispute['decision_result'],
            'decision_note' => $dispute['decision_note'],
            'admin_id' => $dispute['admin_id'] ? (int)$dispute['admin_id'] : null,
            'admin_username' => $dispute['admin_username'],
            'created_at' => $dispute['created_at'],
            'updated_at' => $dispute['updated_at'],
            'task' => [
                'id' => $dispute['task_id'],
                'title' => $dispute['task_title'],
                'reward_point' => (int)$dispute['reward_point'],
                'creator_id' => (int)$dispute['creator_id'],
                'participant_id' => $dispute['participant_id'] ? (int)$dispute['participant_id'] : null,
                'creator_name' => $dispute['creator_name'],
                'participant_name' => $dispute['participant_name']
            ],
            'submitter' => [
                'id' => isset($dispute['user_id']) ? (int)$dispute['user_id'] : null,
                'name' => $dispute['submitter_name'],
                'email' => $dispute['submitter_email']
            ]
        ];
    }, $disputes);
    
    // 統計資料
    $statsQuery = "
        SELECT 
            COUNT(*) as total_disputes,
            SUM(CASE WHEN status = 'submitted' THEN 1 ELSE 0 END) as submitted_count,
            SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) as in_progress_count,
            SUM(CASE WHEN status = 'resolved' THEN 1 ELSE 0 END) as resolved_count
        FROM task_dispute_events
    ";
    
    $statsStmt = $db->prepare($statsQuery);
    $statsStmt->execute();
    $stats = $statsStmt->fetch(PDO::FETCH_ASSOC);
    
    Response::success([
        'items' => $formattedDisputes,
        'pagination' => [
            'current_page' => $page,
            'per_page' => $perPage,
            'total' => (int)$totalCount,
            'total_pages' => (int)ceil($totalCount / $perPage),
            'has_next' => $page < ceil($totalCount / $perPage),
            'has_prev' => $page > 1
        ],
        'stats' => [
            'total_disputes' => (int)$stats['total_disputes'],
            'submitted_count' => (int)$stats['submitted_count'],
            'in_progress_count' => (int)$stats['in_progress_count'],
            'resolved_count' => (int)$stats['resolved_count']
        ]
    ], 'Disputes retrieved successfully');

} catch (PDOException $e) {
    error_log("Database error in admin disputes list: " . $e->getMessage());
    Response::serverError('Database error occurred');
} catch (Exception $e) {
    error_log("Error in admin disputes list: " . $e->getMessage());
    Response::serverError('An error occurred while retrieving disputes');
}
?>
