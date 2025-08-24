<?php
/**
 * GET /api/wallet/fee-settings.php
 * 手續費設定API - 返回當前生效的手續費設定
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
    
    $db = Database::getInstance();
    
    // 獲取當前生效的手續費設定
    $feeQuery = "
        SELECT id, rate, description, is_active, updated_by, created_at, updated_at
        FROM task_completion_points_fee_settings 
        WHERE is_active = 1 
        ORDER BY updated_at DESC 
        LIMIT 1
    ";
    
    $feeSettings = $db->fetch($feeQuery);
    
    if (!$feeSettings) {
        // 如果沒有設定，返回預設值（無手續費）
        Response::success([
            'fee_enabled' => false,
            'rate' => 0.0000,
            'rate_percentage' => '0.00%',
            'description' => 'No fee settings configured',
            'calculation_example' => [
                'task_reward' => 100,
                'fee_amount' => 0,
                'creator_receives' => 100,
                'acceptor_receives' => 100
            ]
        ], 'No active fee settings found - fees disabled');
    }
    
    $rate = (float)$feeSettings['rate'];
    $ratePercentage = number_format($rate * 100, 2) . '%';
    
    // 計算範例
    $exampleReward = 100;
    $exampleFee = max(0, round($exampleReward * $rate)); // 四捨五入取整數
    
    Response::success([
        'fee_enabled' => true,
        'settings' => [
            'id' => (int)$feeSettings['id'],
            'rate' => $rate,
            'rate_percentage' => $ratePercentage,
            'description' => $feeSettings['description'],
            'updated_by' => $feeSettings['updated_by'],
            'created_at' => $feeSettings['created_at'],
            'updated_at' => $feeSettings['updated_at']
        ],
        'calculation_rules' => [
            'formula' => 'fee = round(reward_points * rate)',
            'rounding' => 'Round to nearest integer (四捨五入)',
            'minimum_fee' => 0,
            'charged_to' => 'Task creator (發布者)'
        ],
        'calculation_example' => [
            'task_reward' => $exampleReward,
            'fee_rate' => $ratePercentage,
            'fee_amount' => $exampleFee,
            'creator_pays' => $exampleReward + $exampleFee,
            'acceptor_receives' => $exampleReward,
            'platform_receives' => $exampleFee
        ]
    ], 'Fee settings retrieved successfully');
    
} catch (Exception $e) {
    error_log("Fee settings error: " . $e->getMessage());
    Response::error('Failed to retrieve fee settings: ' . $e->getMessage(), 500);
}
?>
