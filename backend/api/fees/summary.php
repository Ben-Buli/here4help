<?php
/**
 * GET /api/fees/summary.php
 * 手續費統計API - 統計所有有效手續費入帳總額
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    // 驗證JWT Token（管理員權限檢查可在此添加）
    $tokenValidation = JWTManager::validateRequest();
    if (!$tokenValidation['valid']) {
        Response::error($tokenValidation['message'], 401);
    }
    $tokenData = $tokenValidation['payload'];
    
    $db = Database::getInstance();
    
    // 獲取查詢參數
    $fromDate = $_GET['from'] ?? null;
    $toDate = $_GET['to'] ?? null;
    $feeType = $_GET['fee_type'] ?? 'task_completion';
    
    // 建構 WHERE 條件
    $whereConditions = ['1=1'];
    $params = [];
    
    if ($feeType && in_array($feeType, ['task_completion'])) {
        $whereConditions[] = 'fee_type = ?';
        $params[] = $feeType;
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
    
    // 獲取手續費統計
    $summaryQuery = "
        SELECT 
            fee_type,
            COUNT(*) as count,
            SUM(amount_points) as total_points,
            AVG(rate) as avg_rate,
            MIN(created_at) as first_fee_date,
            MAX(created_at) as last_fee_date
        FROM fee_revenue_ledger 
        WHERE $whereClause
        GROUP BY fee_type
    ";
    
    $summaryResults = $db->fetchAll($summaryQuery, $params);
    
    // 獲取每日統計（最近30天或指定日期範圍）
    $dailyStatsQuery = "
        SELECT 
            DATE(created_at) as fee_date,
            COUNT(*) as daily_count,
            SUM(amount_points) as daily_total
        FROM fee_revenue_ledger 
        WHERE $whereClause
        GROUP BY DATE(created_at)
        ORDER BY fee_date DESC
        LIMIT 30
    ";
    
    $dailyStats = $db->fetchAll($dailyStatsQuery, $params);
    
    // 獲取費率分佈統計
    $rateDistributionQuery = "
        SELECT 
            rate,
            COUNT(*) as count,
            SUM(amount_points) as total_points
        FROM fee_revenue_ledger 
        WHERE $whereClause
        GROUP BY rate
        ORDER BY rate ASC
    ";
    
    $rateDistribution = $db->fetchAll($rateDistributionQuery, $params);
    
    // 格式化結果
    $formattedSummary = [];
    $totalPoints = 0;
    $totalCount = 0;
    
    foreach ($summaryResults as $summary) {
        $totalPoints += (int)$summary['total_points'];
        $totalCount += (int)$summary['count'];
        
        $formattedSummary[$summary['fee_type']] = [
            'count' => (int)$summary['count'],
            'total_points' => (int)$summary['total_points'],
            'avg_rate' => round((float)$summary['avg_rate'], 4),
            'avg_rate_percentage' => number_format((float)$summary['avg_rate'] * 100, 2) . '%',
            'first_fee_date' => $summary['first_fee_date'],
            'last_fee_date' => $summary['last_fee_date']
        ];
    }
    
    // 格式化每日統計
    $formattedDailyStats = array_map(function($stat) {
        return [
            'date' => $stat['fee_date'],
            'count' => (int)$stat['daily_count'],
            'total_points' => (int)$stat['daily_total']
        ];
    }, $dailyStats);
    
    // 格式化費率分佈
    $formattedRateDistribution = array_map(function($rate) {
        return [
            'rate' => (float)$rate['rate'],
            'rate_percentage' => number_format((float)$rate['rate'] * 100, 2) . '%',
            'count' => (int)$rate['count'],
            'total_points' => (int)$rate['total_points']
        ];
    }, $rateDistribution);
    
    Response::success([
        'summary' => [
            'total_points' => $totalPoints,
            'total_count' => $totalCount,
            'by_fee_type' => $formattedSummary
        ],
        'daily_statistics' => $formattedDailyStats,
        'rate_distribution' => $formattedRateDistribution,
        'filters' => [
            'from_date' => $fromDate,
            'to_date' => $toDate,
            'fee_type' => $feeType
        ],
        'period_info' => [
            'query_period' => $fromDate && $toDate 
                ? "$fromDate to $toDate" 
                : 'All time',
            'days_covered' => count($formattedDailyStats)
        ]
    ], 'Fee summary retrieved successfully');
    
} catch (Exception $e) {
    error_log("Fee summary error: " . $e->getMessage());
    Response::error('Failed to retrieve fee summary: ' . $e->getMessage(), 500);
}
?>
