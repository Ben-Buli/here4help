<?php
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
    exit;
}

try {
    $db = Database::getInstance();
    
    // 獲取查詢參數
    $page = isset($_GET['page']) ? (int)$_GET['page'] : 1;
    $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 20;
    $status = $_GET['status'] ?? ''; // 'used' or 'unused'
    $search = $_GET['search'] ?? '';
    
    // 計算偏移量
    $offset = ($page - 1) * $limit;
    
    // 構建查詢條件
    $whereConditions = [];
    $params = [];
    
    if ($status === 'used') {
        $whereConditions[] = "rc.is_used = 1";
    } elseif ($status === 'unused') {
        $whereConditions[] = "rc.is_used = 0";
    }
    
    if (!empty($search)) {
        $whereConditions[] = "(rc.referral_code LIKE ? OR u.name LIKE ? OR u.nickname LIKE ? OR u.email LIKE ?)";
        $searchParam = "%{$search}%";
        $params = array_merge($params, [$searchParam, $searchParam, $searchParam, $searchParam]);
    }
    
    $whereClause = !empty($whereConditions) ? 'WHERE ' . implode(' AND ', $whereConditions) : '';
    
    // 獲取總數
    $countSql = "
        SELECT COUNT(*) as total
        FROM referral_codes rc
        JOIN users u ON rc.user_id = u.id
        {$whereClause}
    ";
    $totalResult = $db->fetch($countSql, $params);
    $total = $totalResult['total'];
    
    // 獲取推薦碼列表
    $sql = "
        SELECT 
            rc.id,
            rc.user_id,
            rc.referral_code,
            rc.is_used,
            rc.used_by_user_id,
            rc.created_at,
            rc.updated_at,
            u.name as user_name,
            u.nickname as user_nickname,
            u.email as user_email,
            u.status as user_status,
            used_user.name as used_by_name,
            used_user.nickname as used_by_nickname
        FROM referral_codes rc
        JOIN users u ON rc.user_id = u.id
        LEFT JOIN users used_user ON rc.used_by_user_id = used_user.id
        {$whereClause}
        ORDER BY rc.created_at DESC
        LIMIT ? OFFSET ?
    ";
    
    $params[] = $limit;
    $params[] = $offset;
    
    $referralCodes = $db->fetchAll($sql, $params);
    
    // 計算分頁資訊
    $totalPages = ceil($total / $limit);
    
    Response::success('Referral codes retrieved successfully', [
        'referral_codes' => $referralCodes,
        'pagination' => [
            'current_page' => $page,
            'total_pages' => $totalPages,
            'total_items' => $total,
            'items_per_page' => $limit,
            'has_next' => $page < $totalPages,
            'has_prev' => $page > 1
        ],
        'filters' => [
            'status' => $status,
            'search' => $search
        ]
    ]);
    
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage());
}
?> 