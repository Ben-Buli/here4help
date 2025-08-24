<?php
/**
 * GET /api/wallet/deposit-requests.php
 * 儲值申請記錄API - 獲取用戶的儲值申請歷史
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
    $status = $_GET['status'] ?? null;
    $fromDate = $_GET['from_date'] ?? null;
    $toDate = $_GET['to_date'] ?? null;
    
    $offset = ($page - 1) * $perPage;
    
    // 建構 WHERE 條件
    $whereConditions = ['user_id = ?'];
    $params = [$userId];
    
    if ($status && in_array($status, ['pending', 'approved', 'rejected'])) {
        $whereConditions[] = 'status = ?';
        $params[] = $status;
    }
    
    if ($fromDate && preg_match('/^\d{4}-\d{2}-\d{2}$/', $fromDate)) {
        $whereConditions[] = 'DATE(created_at) >= ?';
        $params[] = $fromDate;
    }
    
    if ($toDate && preg_match('/^\d{4}-\d{2}-\d{2}$/', $toDate)) {
        $whereConditions[] = 'DATE(created_at) <= ?';
        $params[] = $toDate;
    }
    
    $whereClause = implode(' AND ', $whereConditions);
    
    // 獲取總記錄數
    $countQuery = "SELECT COUNT(*) as total FROM point_deposit_requests WHERE $whereClause";
    $totalResult = $db->fetch($countQuery, $params);
    $total = (int)$totalResult['total'];
    
    // 獲取儲值申請記錄
    $requestsQuery = "
        SELECT 
            pdr.id, 
            pdr.user_id, 
            pdr.amount_points,
            pdr.bank_account_last5,
            pdr.status, 
            pdr.approver_reply_description, 
            pdr.approver_id,
            pdr.created_at, 
            pdr.updated_at,
            u.name AS user_name, 
            u.email AS user_email,
            a.full_name AS approver_name
        FROM point_deposit_requests pdr
        LEFT JOIN users u ON pdr.user_id = u.id
        LEFT JOIN admins a ON pdr.approver_id = a.id
        WHERE $whereClause
        ORDER BY pdr.created_at DESC, pdr.id DESC
        LIMIT $perPage OFFSET $offset
    ";
    
    $requests = $db->fetchAll($requestsQuery, $params);
    
    // 格式化儲值申請記錄
    $formattedRequests = array_map(function($request) {
        return [
            'id' => (int)$request['id'],
            'user_id' => (int)$request['user_id'],
            'amount_points' => (int)$request['amount_points'],
            'bank_account_last5' => $request['bank_account_last5'],
            'status' => $request['status'],
            'approver_reply_description' => $request['approver_reply_description'],
            'approver_id' => $request['approver_id'] ? (int)$request['approver_id'] : null,
            'approver_name' => $request['approver_name'],
            'created_at' => $request['created_at'],
            'updated_at' => $request['updated_at'],
            'user_name' => $request['user_name'],
            'user_email' => $request['user_email'],
            'formatted_amount' => '+' . number_format($request['amount_points']),
            'status_display' => _getStatusDisplay($request['status']),
            'status_color' => _getStatusColor($request['status'])
        ];
    }, $requests);
    
    // 計算分頁資訊
    $totalPages = ceil($total / $perPage);
    $hasNextPage = $page < $totalPages;
    $hasPrevPage = $page > 1;
    
    // 獲取狀態統計
    $statsQuery = "
        SELECT status, 
               COUNT(*) as count,
               SUM(amount_points) as total_amount
        FROM point_deposit_requests 
        WHERE user_id = ?
        GROUP BY status
    ";
    
    $stats = $db->fetchAll($statsQuery, [$userId]);
    $formattedStats = new stdClass();
    
    foreach ($stats as $stat) {
        $formattedStats->{$stat['status']} = [
            'count' => (int)$stat['count'],
            'total_amount' => (int)$stat['total_amount'],
            'display_name' => _getStatusDisplay($stat['status'])
        ];
    }
    
    Response::success([
        'requests' => $formattedRequests,
        'pagination' => [
            'current_page' => $page,
            'per_page' => $perPage,
            'total' => $total,
            'total_pages' => $totalPages,
            'has_next_page' => $hasNextPage,
            'has_prev_page' => $hasPrevPage
        ],
        'filters' => [
            'status' => $status,
            'from_date' => $fromDate,
            'to_date' => $toDate
        ],
        'statistics' => $formattedStats,
        'available_statuses' => [
            'pending' => 'Pending Review',
            'approved' => 'Approved',
            'rejected' => 'Rejected'
        ]
    ], 'Deposit requests retrieved successfully');
    
} catch (Exception $e) {
    error_log("Deposit requests error: " . $e->getMessage());
    Response::error('Failed to retrieve deposit requests: ' . $e->getMessage(), 500);
}

/**
 * 獲取狀態顯示名稱
 */
function _getStatusDisplay($status) {
    $statusNames = [
        'pending' => 'Pending Review',
        'approved' => 'Approved', 
        'rejected' => 'Rejected'
    ];
    
    return $statusNames[$status] ?? ucfirst($status);
}

/**
 * 獲取狀態顏色
 */
function _getStatusColor($status) {
    $statusColors = [
        'pending' => 'orange',
        'approved' => 'green',
        'rejected' => 'red'
    ];
    
    return $statusColors[$status] ?? 'grey';
}
?>
