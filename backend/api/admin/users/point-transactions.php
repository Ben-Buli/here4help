<?php
/**
 * GET /api/admin/users/point-transactions.php
 * 管理員查詢所有用戶點數交易記錄API
 */

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../utils/Response.php';
require_once __DIR__ . '/../../../utils/JWTManager.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    // 驗證JWT Token（需要管理員權限）
    $tokenData = JWTManager::validateRequest();
    
    // TODO: 添加管理員權限檢查
    // if (!isAdmin($tokenData['user_id'])) {
    //     Response::error('Insufficient permissions', 403);
    // }
    
    $db = Database::getInstance();
    
    // 獲取查詢參數
    $userId = $_GET['user_id'] ?? null;
    $transactionType = $_GET['transaction_type'] ?? null;
    $fromDate = $_GET['from'] ?? null;
    $toDate = $_GET['to'] ?? null;
    $page = max(1, (int)($_GET['page'] ?? 1));
    $perPage = min(100, max(10, (int)($_GET['per_page'] ?? 20)));
    
    $offset = ($page - 1) * $perPage;
    
    // 建構 WHERE 條件
    $whereConditions = ['1=1'];
    $params = [];
    
    if ($userId && is_numeric($userId)) {
        $whereConditions[] = 'pt.user_id = ?';
        $params[] = $userId;
    }
    
    if ($transactionType && in_array($transactionType, ['earn', 'spend', 'deposit', 'fee', 'refund', 'adjustment'])) {
        $whereConditions[] = 'pt.transaction_type = ?';
        $params[] = $transactionType;
    }
    
    if ($fromDate && preg_match('/^\d{4}-\d{2}-\d{2}$/', $fromDate)) {
        $whereConditions[] = 'DATE(pt.created_at) >= ?';
        $params[] = $fromDate;
    }
    
    if ($toDate && preg_match('/^\d{4}-\d{2}-\d{2}$/', $toDate)) {
        $whereConditions[] = 'DATE(pt.created_at) <= ?';
        $params[] = $toDate;
    }
    
    $whereClause = implode(' AND ', $whereConditions);
    
    // 獲取總記錄數
    $countQuery = "
        SELECT COUNT(*) as total 
        FROM point_transactions pt 
        WHERE $whereClause
    ";
    $totalResult = $db->fetch($countQuery, $params);
    $total = (int)$totalResult['total'];
    
    // 獲取交易記錄（包含用戶資訊）
    $transactionsQuery = "
        SELECT 
            pt.description, pt.related_task_id, pt.related_order_id, pt.status, pt.created_at,
            u.name as user_name, u.nickname as user_nickname, u.email as user_email
        FROM point_transactions pt
        LEFT JOIN users u ON pt.user_id = u.id
        WHERE $whereClause
        ORDER BY pt.created_at DESC, pt.id DESC
        LIMIT $perPage OFFSET $offset
    ";
    
    $transactions = $db->fetchAll($transactionsQuery, $params);
    
    // 獲取統計資訊
    $summaryQuery = "
        SELECT 
            transaction_type,
            COUNT(*) as count,
            SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as total_income,
            SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as total_expense,
            AVG(ABS(amount)) as avg_amount
        FROM point_transactions pt
        WHERE $whereClause
        GROUP BY transaction_type
    ";
    
    $summaryResults = $db->fetchAll($summaryQuery, $params);
    
    // 格式化交易記錄
    $formattedTransactions = array_map(function($transaction) {
        return [
            'id' => (int)$transaction['id'],
            'user_id' => (int)$transaction['user_id'],
            'user_info' => [
                'name' => $transaction['user_name'],
                'nickname' => $transaction['user_nickname'],
                'email' => $transaction['user_email'],
                'display_name' => $transaction['user_nickname'] ?: $transaction['user_name']
            ],
            'transaction_type' => $transaction['transaction_type'],
            'amount' => (int)$transaction['amount'],
            'description' => $transaction['description'],
            'related_task_id' => $transaction['related_task_id'],
            'related_order_id' => $transaction['related_order_id'] ? (int)$transaction['related_order_id'] : null,
            'status' => $transaction['status'],
            'created_at' => $transaction['created_at'],
            'formatted_amount' => ($transaction['amount'] >= 0 ? '+' : '') . number_format($transaction['amount']),
            'is_income' => (int)$transaction['amount'] > 0,
            'display_type' => _getDisplayType($transaction['transaction_type'])
        ];
    }, $transactions);
    
    // 格式化統計資訊
    $formattedSummary = [];
    $totalIncome = 0;
    $totalExpense = 0;
    $totalTransactions = 0;
    
    foreach ($summaryResults as $summary) {
        $totalIncome += (int)$summary['total_income'];
        $totalExpense += (int)$summary['total_expense'];
        $totalTransactions += (int)$summary['count'];
        
        $formattedSummary[$summary['transaction_type']] = [
            'count' => (int)$summary['count'],
            'total_income' => (int)$summary['total_income'],
            'total_expense' => (int)$summary['total_expense'],
            'avg_amount' => round((float)$summary['avg_amount'], 2),
            'display_name' => _getDisplayType($summary['transaction_type'])
        ];
    }
    
    // 計算分頁資訊
    $totalPages = ceil($total / $perPage);
    $hasNextPage = $page < $totalPages;
    $hasPrevPage = $page > 1;
    
    Response::success([
        'transactions' => $formattedTransactions,
        'pagination' => [
            'current_page' => $page,
            'per_page' => $perPage,
            'total' => $total,
            'total_pages' => $totalPages,
            'has_next_page' => $hasNextPage,
            'has_prev_page' => $hasPrevPage
        ],
        'summary' => [
            'total_transactions' => $totalTransactions,
            'total_income' => $totalIncome,
            'total_expense' => $totalExpense,
            'net_change' => $totalIncome - $totalExpense,
            'by_type' => $formattedSummary
        ],
        'filters' => [
            'user_id' => $userId ? (int)$userId : null,
            'transaction_type' => $transactionType,
            'from_date' => $fromDate,
            'to_date' => $toDate
        ],
        'available_types' => [
            'earn' => 'Task Earnings',
            'spend' => 'Task Spending',
            'deposit' => 'Deposits',
            'fee' => 'Fees',
            'refund' => 'Refunds',
            'adjustment' => 'Adjustments'
        ]
    ], 'User point transactions retrieved successfully');
    
} catch (Exception $e) {
    error_log("Admin user transactions error: " . $e->getMessage());
    Response::error('Failed to retrieve user transactions: ' . $e->getMessage(), 500);
}

/**
 * 獲取交易類型的顯示名稱
 */
function _getDisplayType($transactionType) {
    $displayTypes = [
        'earn' => 'Task Earnings',
        'spend' => 'Task Spending', 
        'deposit' => 'Deposit',
        'fee' => 'Service Fee',
        'refund' => 'Refund',
        'adjustment' => 'Adjustment'
    ];
    
    return $displayTypes[$transactionType] ?? ucfirst($transactionType);
}
?>
