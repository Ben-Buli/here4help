<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

/**
 * GET /api/wallet/withdraw-fee-settings.php
 * 提領手續費設定
 */

require_once dirname(__DIR__, 2) . '/config/database.php';
require_once dirname(__DIR__, 2) . '/utils/Response.php';
require_once dirname(__DIR__, 2) . '/utils/JWTManager.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    $auth = JWTManager::validateRequest();
    if (!$auth['valid']) {
        Response::unauthorized($auth['message'] ?? 'Unauthorized');
    }

    $db = Database::getInstance();
    $minWithdrawPoints = 100;

    $row = $db->fetch("SELECT id, rate, description, is_active, created_at, updated_at FROM withdraw_fee_settings WHERE is_active = 1 ORDER BY id DESC LIMIT 1");

    if (!$row) {
        $row = [
            'id' => 0,
            'rate' => 0.0,
            'description' => 'No withdraw fee settings configured',
            'is_active' => 0,
            'created_at' => date('Y-m-d H:i:s'),
            'updated_at' => date('Y-m-d H:i:s'),
        ];
    }

    Response::success([
        'fee_setting' => $row,
        'min_withdraw_points' => $minWithdrawPoints,
    ], 'Withdraw fee settings retrieved successfully');
} catch (Exception $e) {
    Response::serverError('Failed to retrieve withdraw fee settings: ' . $e->getMessage());
}
?>
