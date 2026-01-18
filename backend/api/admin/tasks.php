<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

/**
 * 管理員任務列表 API
 * GET /api/admin/tasks
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
    $perPage = min(100, max(10, (int)($_GET['per_page'] ?? 25)));
    $status = $_GET['status'] ?? '';
    $creatorId = $_GET['creator_id'] ?? '';
    $participantId = $_GET['participant_id'] ?? '';
    $search = trim($_GET['search'] ?? '');
    $dateFrom = $_GET['date_from'] ?? '';
    $dateTo = $_GET['date_to'] ?? '';
    $sortBy = $_GET['sort_by'] ?? 'created_at';
    $sortOrder = $_GET['sort_order'] ?? 'desc';
    
    $offset = ($page - 1) * $perPage;
    
    // 構建查詢條件
    $whereConditions = [];
    $params = [];
    
    if (!empty($status)) {
        if (is_numeric($status)) {
            $whereConditions[] = "t.status_id = ?";
            $params[] = (int)$status;
        } else {
            $whereConditions[] = "s.code = ?";
            $params[] = $status;
        }
    }
    
    if (!empty($creatorId)) {
        $whereConditions[] = "t.creator_id = ?";
        $params[] = (int)$creatorId;
    }
    
    if (!empty($participantId)) {
        $whereConditions[] = "t.participant_id = ?";
        $params[] = (int)$participantId;
    }
    
    /**
     * Search 欄位支援以下查詢：
     * - 任務標題 (Task title)
     * - 任務描述 (Task description)
     * - 任務 ID (Task ID) - UUID 格式
     * - 創建者 ID (Creator ID) - 數字
     * - 參與者 ID (Participant ID) - 數字
     * - 創建者名稱 (Creator name)
     * - 參與者名稱 (Participant name)
     */
    if (!empty($search)) {
        // 基本搜尋條件：標題、描述、任務ID、創建者名稱、參與者名稱
        $searchConditions = "(t.title LIKE ? OR t.description LIKE ? OR t.id LIKE ? OR creator.name LIKE ? OR participant.name LIKE ?";
        $searchTerm = "%{$search}%";
        $searchParams = [$searchTerm, $searchTerm, $searchTerm, $searchTerm, $searchTerm];
        
        // 如果是純數字，也搜尋 creator_id 和 participant_id
        if (is_numeric($search)) {
            $searchConditions .= " OR t.creator_id = ? OR t.participant_id = ?";
            $searchParams[] = (int)$search;
            $searchParams[] = (int)$search;
        }
        
        $searchConditions .= ")";
        $whereConditions[] = $searchConditions;
        $params = array_merge($params, $searchParams);
    }
    
    if (!empty($dateFrom)) {
        $whereConditions[] = "DATE(t.created_at) >= ?";
        $params[] = $dateFrom;
    }
    
    if (!empty($dateTo)) {
        $whereConditions[] = "DATE(t.created_at) <= ?";
        $params[] = $dateTo;
    }
    
    $whereClause = !empty($whereConditions) ? 'WHERE ' . implode(' AND ', $whereConditions) : '';
    
    // 驗證排序欄位
    $allowedSortFields = ['created_at', 'updated_at', 'title', 'reward_point', 'deadline'];
    if (!in_array($sortBy, $allowedSortFields)) {
        $sortBy = 'created_at';
    }
    
    $sortOrder = strtoupper($sortOrder) === 'ASC' ? 'ASC' : 'DESC';
    
    // 查詢任務列表
    $sql = "
        SELECT 
            t.id,
            t.title,
            t.description,
            t.reward_point,
            t.deadline,
            t.task_date,
            t.created_at,
            t.updated_at,
            t.creator_id,
            t.participant_id,
            s.id as status_id,
            s.code as status_code,
            s.display_name as status_display,
            creator.name as creator_name,
            creator.email as creator_email,
            participant.name as participant_name,
            participant.email as participant_email
        FROM tasks t
        LEFT JOIN task_statuses s ON t.status_id = s.id
        LEFT JOIN users creator ON t.creator_id = creator.id
        LEFT JOIN users participant ON t.participant_id = participant.id
        {$whereClause}
        ORDER BY t.{$sortBy} {$sortOrder}
        LIMIT ? OFFSET ?
    ";
    
    $params[] = $perPage;
    $params[] = $offset;
    
    $stmt = $db->prepare($sql);
    $stmt->execute($params);
    $tasks = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // 查詢總數
    $countSql = "
        SELECT COUNT(*) as total
        FROM tasks t
        LEFT JOIN task_statuses s ON t.status_id = s.id
        LEFT JOIN users creator ON t.creator_id = creator.id
        LEFT JOIN users participant ON t.participant_id = participant.id
        {$whereClause}
    ";
    
    $countParams = array_slice($params, 0, -2); // 移除 LIMIT 和 OFFSET 參數
    $countStmt = $db->prepare($countSql);
    $countStmt->execute($countParams);
    $totalCount = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // 查詢統計資料
    $statsStmt = $db->prepare("
        SELECT 
            COUNT(*) as total_tasks,
            SUM(CASE WHEN s.code IN ('open', 'in_progress') THEN 1 ELSE 0 END) as active_tasks,
            SUM(CASE WHEN s.code = 'pending_confirmation' THEN 1 ELSE 0 END) as pending_tasks,
            SUM(CASE WHEN s.code = 'dispute' THEN 1 ELSE 0 END) as disputed_tasks
        FROM tasks t
        LEFT JOIN task_statuses s ON t.status_id = s.id
    ");
    $statsStmt->execute();
    $stats = $statsStmt->fetch(PDO::FETCH_ASSOC);
    
    // 格式化任務資料
    $formattedTasks = array_map(function($task) {
        return [
            'id' => $task['id'],
            'title' => $task['title'],
            'description' => $task['description'],
            'reward_point' => (int)$task['reward_point'],
            'deadline' => $task['deadline'],
            'task_date' => $task['task_date'],
            'created_at' => $task['created_at'],
            'updated_at' => $task['updated_at'],
            'creator_id' => (int)$task['creator_id'],
            'creator_name' => $task['creator_name'],
            'creator_email' => $task['creator_email'],
            'participant_id' => $task['participant_id'] ? (int)$task['participant_id'] : null,
            'participant_name' => $task['participant_name'],
            'participant_email' => $task['participant_email'],
            'status_id' => (int)$task['status_id'],
            'status_code' => $task['status_code'],
            'status_display' => $task['status_display']
        ];
    }, $tasks);
    
    $pagination = [
        'current_page' => $page,
        'per_page' => $perPage,
        'total' => (int)$totalCount,
        'last_page' => ceil($totalCount / $perPage)
    ];
    
    Response::success([
        'tasks' => $formattedTasks,
        'pagination' => $pagination,
        'stats' => [
            'total_tasks' => (int)$stats['total_tasks'],
            'active_tasks' => (int)$stats['active_tasks'],
            'pending_tasks' => (int)$stats['pending_tasks'],
            'disputed_tasks' => (int)$stats['disputed_tasks']
        ]
    ], 'Tasks retrieved successfully');
    
} catch (Exception $e) {
    error_log("Admin Tasks API Error: " . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}
?>
