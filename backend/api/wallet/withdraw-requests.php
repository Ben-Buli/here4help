<?php
require_once __DIR__ . '/bootstrap.php';
// 載入 PHP 8.4 相容性配置

/**
 * GET/POST /api/wallet/withdraw-requests.php
 * 提領申請：建立與查詢
 */

require_once __DIR__ . '/../../config/database.php';

Response::setCorsHeaders();

if (!in_array($_SERVER['REQUEST_METHOD'], ['GET', 'POST'], true)) {
    Response::error('Method not allowed', 405);
}

try {
    $auth = JWTManager::validateRequest();
    if (!$auth['valid']) {
        Response::error($auth['message'], 401);
    }
    $userId = (int)$auth['payload']['user_id'];

    $db = Database::getInstance();
    $minWithdrawPoints = 100;

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $page = max(1, (int)($_GET['page'] ?? 1));
        $perPage = min(50, max(10, (int)($_GET['per_page'] ?? 20)));
        $status = $_GET['status'] ?? null;
        $fromDate = $_GET['from_date'] ?? null;
        $toDate = $_GET['to_date'] ?? null;
        $offset = ($page - 1) * $perPage;

        $whereConditions = ['pwr.user_id = ?'];
        $params = [$userId];

        if ($status && in_array($status, ['pending', 'approved', 'rejected', 'cancelled', 'paid'], true)) {
            $whereConditions[] = 'pwr.status = ?';
            $params[] = $status;
        }

        if ($fromDate && preg_match('/^\d{4}-\d{2}-\d{2}$/', $fromDate)) {
            $whereConditions[] = 'DATE(pwr.created_at) >= ?';
            $params[] = $fromDate;
        }

        if ($toDate && preg_match('/^\d{4}-\d{2}-\d{2}$/', $toDate)) {
            $whereConditions[] = 'DATE(pwr.created_at) <= ?';
            $params[] = $toDate;
        }

        $whereClause = implode(' AND ', $whereConditions);

        $countQuery = "SELECT COUNT(*) as total FROM point_withdraw_requests pwr WHERE $whereClause";
        $totalResult = $db->fetch($countQuery, $params);
        $total = (int)$totalResult['total'];

        $listQuery = "
            SELECT 
                pwr.*,
                a.full_name AS admin_name
            FROM point_withdraw_requests pwr
            LEFT JOIN admins a ON pwr.admin_id = a.id
            WHERE $whereClause
            ORDER BY pwr.created_at DESC, pwr.id DESC
            LIMIT $perPage OFFSET $offset
        ";
        $rows = $db->fetchAll($listQuery, $params);

        $formatted = array_map(function ($row) {
            return [
                'id' => (int)$row['id'],
                'user_id' => (int)$row['user_id'],
                'amount_points' => (int)$row['amount_points'],
                'fee_rate' => (float)$row['fee_rate'],
                'fee_points' => (int)$row['fee_points'],
                'total_deduct_points' => (int)$row['total_deduct_points'],
                'net_payout_points' => (int)$row['net_payout_points'],
                'status' => $row['status'],
                'admin_id' => $row['admin_id'] ? (int)$row['admin_id'] : null,
                'admin_name' => $row['admin_name'],
                'admin_reply' => $row['admin_reply'],
                'reviewed_at' => $row['reviewed_at'],
                'paid_at' => $row['paid_at'],
                'cancelled_at' => $row['cancelled_at'],
                'created_at' => $row['created_at'],
                'updated_at' => $row['updated_at'],
            ];
        }, $rows);

        $totalPages = (int)ceil($total / $perPage);
        Response::success([
            'requests' => $formatted,
            'pagination' => [
                'current_page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'total_pages' => $totalPages,
                'has_next_page' => $page < $totalPages,
                'has_prev_page' => $page > 1,
            ],
            'filters' => [
                'status' => $status,
                'from_date' => $fromDate,
                'to_date' => $toDate,
            ],
            'min_withdraw_points' => $minWithdrawPoints,
        ], 'Withdraw requests retrieved successfully');
    }

    $input = json_decode(file_get_contents('php://input'), true) ?? [];
    $amountPoints = isset($input['amount_points']) ? (int)$input['amount_points'] : 0;

    if ($amountPoints < $minWithdrawPoints) {
        Response::validationError([
            'amount_points' => "Minimum withdraw amount is {$minWithdrawPoints} points"
        ]);
    }

    $feeSetting = $db->fetch("SELECT rate FROM withdraw_fee_settings WHERE is_active = 1 ORDER BY id DESC LIMIT 1");
    if (!$feeSetting || !isset($feeSetting['rate'])) {
        Response::error('Withdraw fee is not configured. Please contact support.', 422);
    }

    $feeRate = (float)$feeSetting['rate'];
    if ($feeRate < 0 || $feeRate >= 1) {
        Response::error('Withdraw fee rate is invalid. Please contact support.', 422);
    }

    $feePoints = (int)round($amountPoints * $feeRate);
    $totalDeduct = $amountPoints + $feePoints;

    // 查詢可用點數（扣除任務占用與提領凍結）
    $user = $db->fetch("SELECT points FROM users WHERE id = ?", [$userId]);
    if (!$user) {
        Response::error('User not found', 404);
    }
    $totalPoints = (int)$user['points'];

    $occupiedResult = $db->fetch(
        "SELECT COALESCE(SUM(CAST(reward_point AS SIGNED)), 0) as occupied_points
         FROM tasks 
         WHERE creator_id = ? 
           AND status_id IN (1, 2, 3, 4)
           AND reward_point IS NOT NULL 
           AND reward_point != ''",
        [$userId]
    );
    $occupiedPoints = (int)$occupiedResult['occupied_points'];

    $frozenResult = $db->fetch(
        "SELECT COALESCE(SUM(total_deduct_points), 0) AS frozen_points
         FROM point_withdraw_requests
         WHERE user_id = ? AND status IN ('pending', 'approved')",
        [$userId]
    );
    $frozenPoints = (int)$frozenResult['frozen_points'];

    $availablePoints = max(0, $totalPoints - $occupiedPoints - $frozenPoints);
    if ($availablePoints < $totalDeduct) {
        Response::validationError([
            'amount_points' => 'Insufficient balance for this withdrawal'
        ]);
    }

    $db->query(
        "INSERT INTO point_withdraw_requests (
            user_id, amount_points, fee_rate, fee_points, total_deduct_points, net_payout_points, status, created_at, updated_at
         ) VALUES (?, ?, ?, ?, ?, ?, 'pending', NOW(), NOW())",
        [$userId, $amountPoints, $feeRate, $feePoints, $totalDeduct, $amountPoints]
    );

    $requestId = (int)$db->lastInsertId();

    $ip = $_SERVER['REMOTE_ADDR'] ?? null;
    $userAgent = $_SERVER['HTTP_USER_AGENT'] ?? null;
    $db->query(
        "INSERT INTO user_active_log
            (user_id, actor_type, actor_id, action, field, old_value, new_value, reason, ip, user_agent, metadata, created_at)
         VALUES (?, 'user', ?, 'withdraw_request', 'withdraw_status', NULL, 'pending', NULL, ?, ?, ?, NOW())",
        [
            $userId,
            $userId,
            $ip,
            $userAgent,
            json_encode([
                'request_id' => $requestId,
                'amount_points' => $amountPoints,
                'fee_points' => $feePoints,
                'total_deduct_points' => $totalDeduct,
            ]),
        ]
    );

    Response::success([
        'request_id' => $requestId,
        'amount_points' => $amountPoints,
        'fee_rate' => $feeRate,
        'fee_points' => $feePoints,
        'total_deduct_points' => $totalDeduct,
        'net_payout_points' => $amountPoints,
        'status' => 'pending',
        'min_withdraw_points' => $minWithdrawPoints,
    ], 'Withdraw request submitted');
} catch (Exception $e) {
    error_log("Withdraw request error: " . $e->getMessage());
    Response::error('Failed to process withdraw request: ' . $e->getMessage(), 500);
}
?>
