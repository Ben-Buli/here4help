<?php
/**
 * 任務列表 API
 * GET /api/tasks/list.php
 */

require_once '../../config/database.php';
require_once '../../utils/Response.php';

// 設定 CORS 標頭
Response::setCorsHeaders();

// 只允許 GET 請求
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    $db = Database::getInstance();
    
    // 獲取查詢參數
    $status = $_GET['status'] ?? null;
    $location = $_GET['location'] ?? null;
    $language = $_GET['language'] ?? null;
    $limit = (int)($_GET['limit'] ?? 20);
    $offset = (int)($_GET['offset'] ?? 0);
    
    // 建立查詢條件
    $whereConditions = [];
    $params = [];
    
    if ($status) {
        // 支援傳入 code 或 id
        if (is_numeric($status)) {
            $whereConditions[] = "t.status_id = ?";
            $params[] = (int)$status;
        } else {
            $whereConditions[] = "s.code = ?";
            $params[] = $status;
        }
    }
    
    if ($location) {
        $whereConditions[] = "location LIKE ?";
        $params[] = "%$location%";
    }
    
    if ($language) {
        $whereConditions[] = "language_requirement = ?";
        $params[] = $language;
    }
    
    $whereClause = '';
    if (!empty($whereConditions)) {
        $whereClause = 'WHERE ' . implode(' AND ', $whereConditions);
    }
    
    // 查詢任務列表
    // 使用別名並 JOIN 狀態與建立者（僅帶必要欄位）
    $sql = "SELECT 
              t.*, 
              s.id AS status_id,
              s.code AS status_code,
              s.display_name AS status_display,
              s.progress_ratio,
              s.sort_order,
              u.id AS creator_id,
              u.name AS creator_name,
              u.avatar_url AS creator_avatar
            FROM tasks t
            LEFT JOIN task_statuses s ON t.status_id = s.id
            LEFT JOIN users u ON t.creator_id = u.id
            $whereClause
            ORDER BY t.created_at DESC 
            LIMIT ? OFFSET ?";
    $params[] = $limit;
    $params[] = $offset;
    
    $tasks = $db->fetchAll($sql, $params);
    
    // 為每個任務獲取相關的申請問題
    foreach ($tasks as &$task) {
        $questionsSql = "SELECT * FROM application_questions WHERE task_id = ?";
        $questions = $db->fetchAll($questionsSql, [$task['id']]);
        $task['application_questions'] = $questions;
        
        // 將 hashtags 字串轉換為陣列
        if ($task['hashtags']) {
            $task['hashtags'] = explode(',', $task['hashtags']);
        } else {
            $task['hashtags'] = [];
        }
    }
    
    // 獲取總數
    $countSql = "SELECT COUNT(*) as total FROM tasks t 
                 LEFT JOIN task_statuses s ON t.status_id = s.id
                 $whereClause";
    $totalResult = $db->fetch($countSql, array_slice($params, 0, -2));
    $total = $totalResult['total'];
    
    Response::success([
        'tasks' => $tasks,
        'pagination' => [
            'total' => $total,
            'limit' => $limit,
            'offset' => $offset,
            'has_more' => ($offset + $limit) < $total
        ]
    ], 'Tasks retrieved successfully');
    
} catch (Exception $e) {
    Response::serverError('Failed to retrieve tasks: ' . $e->getMessage());
}
?> 