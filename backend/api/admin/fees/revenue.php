<?php
/**
 * GET /api/admin/fees/revenue.php
 * 管理員手續費收入統計API
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
    $fromDate = $_GET['from'] ?? null;
    $toDate = $_GET['to'] ?? null;
    $groupBy = $_GET['group_by'] ?? 'day';
    
    // 驗證 group_by 參數
    if (!in_array($groupBy, ['day', 'month', 'year'])) {
        $groupBy = 'day';
    }
    
    // 建構 WHERE 條件
    $whereConditions = ['1=1'];
    $params = [];
    
    if ($fromDate && preg_match('/^\d{4}-\d{2}-\d{2}$/', $fromDate)) {
        $whereConditions[] = 'DATE(created_at) >= ?';
        $params[] = $fromDate;
    }
    
    if ($toDate && preg_match('/^\d{4}-\d{2}-\d{2}$/', $toDate)) {
        $whereConditions[] = 'DATE(created_at) <= ?';
        $params[] = $toDate;
    }
    
    $whereClause = implode(' AND ', $whereConditions);
    
    // 獲取總收入統計
    $totalRevenueQuery = "
        SELECT 
            COUNT(*) as total_transactions,
            SUM(amount_points) as total_revenue,
            AVG(amount_points) as avg_fee_per_transaction,
            MIN(created_at) as first_transaction_date,
            MAX(created_at) as last_transaction_date
        FROM fee_revenue_ledger 
        WHERE $whereClause
    ";
    
    $totalStats = $db->fetch($totalRevenueQuery, $params);
    
    // 根據 group_by 參數設定日期格式
    $dateFormat = match($groupBy) {
        'year' => '%Y',
        'month' => '%Y-%m',
        default => '%Y-%m-%d'
    };
    
    // 獲取期間統計
    $periodStatsQuery = "
        SELECT 
            DATE_FORMAT(created_at, '$dateFormat') as period,
            COUNT(*) as transaction_count,
            SUM(amount_points) as period_revenue,
            AVG(rate) as avg_rate
        FROM fee_revenue_ledger 
        WHERE $whereClause
        GROUP BY DATE_FORMAT(created_at, '$dateFormat')
        ORDER BY period DESC
        LIMIT 30
    ";
    
    $periodStats = $db->fetchAll($periodStatsQuery, $params);
    
    // 獲取手續費最高的任務
    $topTasksQuery = "
        SELECT 
            f.task_id,
            t.title as task_title,
            SUM(f.amount_points) as total_fees,
            COUNT(*) as fee_count,
            AVG(f.rate) as avg_rate,
            MAX(f.created_at) as last_fee_date
        FROM fee_revenue_ledger f
        LEFT JOIN tasks t ON f.task_id = t.id
        WHERE $whereClause
        GROUP BY f.task_id
        ORDER BY total_fees DESC
        LIMIT 10
    ";
    
    $topTasks = $db->fetchAll($topTasksQuery, $params);
    
    // 獲取費率分佈統計
    $rateDistributionQuery = "
        SELECT 
            rate,
            COUNT(*) as transaction_count,
            SUM(amount_points) as total_revenue
        FROM fee_revenue_ledger 
        WHERE $whereClause
        GROUP BY rate
        ORDER BY rate ASC
    ";
    
    $rateDistribution = $db->fetchAll($rateDistributionQuery, $params);
    
    // 格式化結果
    $formattedPeriodStats = array_map(function($stat) {
        return [
            'period' => $stat['period'],
            'transaction_count' => (int)$stat['transaction_count'],
            'period_revenue' => (int)$stat['period_revenue'],
            'avg_rate' => round((float)$stat['avg_rate'], 4),
            'avg_rate_percentage' => number_format((float)$stat['avg_rate'] * 100, 2) . '%'
        ];
    }, $periodStats);
    
    $formattedTopTasks = array_map(function($task) {
        return [
            'task_id' => $task['task_id'],
            'task_title' => $task['task_title'] ?? 'Unknown Task',
            'total_fees' => (int)$task['total_fees'],
            'fee_count' => (int)$task['fee_count'],
            'avg_rate' => round((float)$task['avg_rate'], 4),
            'avg_rate_percentage' => number_format((float)$task['avg_rate'] * 100, 2) . '%',
            'last_fee_date' => $task['last_fee_date']
        ];
    }, $topTasks);
    
    $formattedRateDistribution = array_map(function($rate) {
        return [
            'rate' => (float)$rate['rate'],
            'rate_percentage' => number_format((float)$rate['rate'] * 100, 2) . '%',
            'transaction_count' => (int)$rate['transaction_count'],
            'total_revenue' => (int)$rate['total_revenue']
        ];
    }, $rateDistribution);
    
    Response::success([
        'total_revenue' => (int)$totalStats['total_revenue'],
        'summary' => [
            'total_transactions' => (int)$totalStats['total_transactions'],
            'total_revenue' => (int)$totalStats['total_revenue'],
            'avg_fee_per_transaction' => round((float)$totalStats['avg_fee_per_transaction'], 2),
            'first_transaction_date' => $totalStats['first_transaction_date'],
            'last_transaction_date' => $totalStats['last_transaction_date']
        ],
        'period_stats' => $formattedPeriodStats,
        'top_tasks' => $formattedTopTasks,
        'rate_distribution' => $formattedRateDistribution,
        'filters' => [
            'from_date' => $fromDate,
            'to_date' => $toDate,
            'group_by' => $groupBy
        ],
        'query_info' => [
            'period_covered' => count($formattedPeriodStats),
            'group_by_format' => $groupBy
        ]
    ], 'Fee revenue statistics retrieved successfully');
    
} catch (Exception $e) {
    error_log("Admin fee revenue error: " . $e->getMessage());
    Response::error('Failed to retrieve fee revenue statistics: ' . $e->getMessage(), 500);
}
?>
