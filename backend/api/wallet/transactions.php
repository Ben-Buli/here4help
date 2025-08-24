<?php
/**
 * GET /api/wallet/transactions.php
 * 點數交易記錄API - 獲取用戶的點數交易歷史
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
    $transactionType = $_GET['transaction_type'] ?? null;
    $fromDate = $_GET['from_date'] ?? null;
    $toDate = $_GET['to_date'] ?? null;
    
    $offset = ($page - 1) * $perPage;
    
    // 建構 WHERE 條件
    $whereConditions = ['user_id = ?'];
    $params = [$userId];
    
    if ($transactionType && in_array($transactionType, ['earn', 'spend', 'deposit', 'fee', 'refund', 'adjustment'])) {
        $whereConditions[] = 'transaction_type = ?';
        $params[] = $transactionType;
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
    $countQuery = "SELECT COUNT(*) as total FROM point_transactions WHERE $whereClause";
    $totalResult = $db->fetch($countQuery, $params);
    $total = (int)$totalResult['total'];
    
    // 獲取交易記錄
    $transactionsQuery = "
        SELECT id, transaction_type, amount,  description, 
               related_task_id, status, created_at
        FROM point_transactions 
        WHERE $whereClause
        ORDER BY created_at DESC, id DESC
        LIMIT $perPage OFFSET $offset
    ";
    
    $transactions = $db->fetchAll($transactionsQuery, $params);
    
    // 格式化交易記錄
    $formattedTransactions = array_map(function($transaction) {
        return [
            'id' => (int)$transaction['id'],
            'transaction_type' => $transaction['transaction_type'],
            'amount' => (int)$transaction['amount'],
          
            'description' => $transaction['description'],
            'related_task_id' => $transaction['related_task_id'],
            'status' => $transaction['status'],
            'created_at' => $transaction['created_at'],
            'formatted_amount' => ($transaction['amount'] >= 0 ? '+' : '') . number_format($transaction['amount']),
            'is_income' => (int)$transaction['amount'] > 0,
            'display_type' => _getDisplayType($transaction['transaction_type'])
        ];
    }, $transactions);
    
    // 計算分頁資訊
    $totalPages = ceil($total / $perPage);
    $hasNextPage = $page < $totalPages;
    $hasPrevPage = $page > 1;
    
    // 獲取交易類型統計
    $statsQuery = "
        SELECT transaction_type, 
               COUNT(*) as count,
               SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as total_income,
               SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as total_expense
        FROM point_transactions 
        WHERE user_id = ?
        GROUP BY transaction_type
    ";
    
    $stats = $db->fetchAll($statsQuery, [$userId]);
    $formattedStats = new stdClass(); // 確保是物件而不是陣列
    
    foreach ($stats as $stat) {
        $formattedStats->{$stat['transaction_type']} = [
            'count' => (int)$stat['count'],
            'total_income' => (int)$stat['total_income'],
            'total_expense' => (int)$stat['total_expense'],
            'display_name' => _getDisplayType($stat['transaction_type'])
        ];
    }
    
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
        'filters' => [
            'transaction_type' => $transactionType,
            'from_date' => $fromDate,
            'to_date' => $toDate
        ],
        'statistics' => $formattedStats,
        'available_types' => [
            'earn' => 'Task Earnings',
            'spend' => 'Task Spending',
            'deposit' => 'Deposits',
            'fee' => 'Fees',
            'refund' => 'Refunds',
            'adjustment' => 'Adjustments'
        ]
    ], 'Transaction history retrieved successfully');
    
} catch (Exception $e) {
    error_log("Transaction history error: " . $e->getMessage());
    Response::error('Failed to retrieve transaction history: ' . $e->getMessage(), 500);
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
