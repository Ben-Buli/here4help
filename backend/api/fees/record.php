<?php
/**
 * POST /api/fees/record.php
 * 手續費記錄API - 在任務完成的原子化交易內，同步記錄手續費入帳到 fee_revenue_ledger
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
}

try {
    // 驗證JWT Token（通常由系統內部調用，但仍需驗證）
    $tokenData = JWTManager::validateRequest();
    
    $db = Database::getInstance();
    
    // 獲取 JSON 數據
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        Response::error('Invalid JSON input', 400);
    }
    
    $taskId = $input['task_id'] ?? null;
    $srcTransactionId = $input['src_transaction_id'] ?? null;
    $payerUserId = $input['payer_user_id'] ?? null;
    $rate = $input['rate'] ?? null;
    $amountPoints = $input['amount_points'] ?? null;
    $note = $input['note'] ?? '';
    
    // 驗證必填欄位
    $errors = [];
    if (!$taskId || !is_numeric($taskId)) {
        $errors['task_id'] = 'Valid task_id is required';
    }
    if (!$srcTransactionId || !is_numeric($srcTransactionId)) {
        $errors['src_transaction_id'] = 'Valid src_transaction_id is required';
    }
    if (!$payerUserId || !is_numeric($payerUserId)) {
        $errors['payer_user_id'] = 'Valid payer_user_id is required';
    }
    if (!is_numeric($rate) || $rate < 0 || $rate > 1) {
        $errors['rate'] = 'Rate must be a decimal between 0 and 1';
    }
    if (!is_numeric($amountPoints) || $amountPoints <= 0) {
        $errors['amount_points'] = 'Amount points must be a positive integer';
    }
    
    if (!empty($errors)) {
        Response::validationError($errors);
    }
    
    // 開始資料庫交易
    $db->beginTransaction();
    
    try {
        // 驗證 src_transaction_id 是否存在
        $srcTransaction = $db->fetch(
            "SELECT id, user_id, amount FROM point_transactions WHERE id = ?",
            [$srcTransactionId]
        );
        
        if (!$srcTransaction) {
            throw new Exception('Source transaction not found');
        }
        
        // 驗證任務是否存在
        $task = $db->fetch(
            "SELECT id, creator_id, reward_point FROM tasks WHERE id = ?",
            [$taskId]
        );
        
        if (!$task) {
            throw new Exception('Task not found');
        }
        
        // 驗證付費用戶是否為任務創建者
        if ((int)$task['creator_id'] !== (int)$payerUserId) {
            throw new Exception('Payer user must be the task creator');
        }
        
        // 檢查是否已經記錄過此交易的手續費
        $existingFee = $db->fetch(
            "SELECT id FROM fee_revenue_ledger WHERE src_transaction_id = ? AND task_id = ?",
            [$srcTransactionId, $taskId]
        );
        
        if ($existingFee) {
            throw new Exception('Fee already recorded for this transaction');
        }
        
        // 插入手續費記錄
        $insertQuery = "
            INSERT INTO fee_revenue_ledger (
                fee_type, src_transaction_id, task_id, payer_user_id, 
                amount_points, rate, note, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
        ";
        
        $db->execute($insertQuery, [
            'task_completion',
            $srcTransactionId,
            $taskId,
            $payerUserId,
            $amountPoints,
            $rate,
            $note
        ]);
        
        $feeId = $db->lastInsertId();
        
        // 提交交易
        $db->commit();
        
        Response::success([
            'fee_id' => (int)$feeId,
            'task_id' => (int)$taskId,
            'src_transaction_id' => (int)$srcTransactionId,
            'payer_user_id' => (int)$payerUserId,
            'amount_points' => (int)$amountPoints,
            'rate' => (float)$rate,
            'rate_percentage' => number_format($rate * 100, 2) . '%',
            'note' => $note,
            'created_at' => date('Y-m-d H:i:s')
        ], 'Fee recorded successfully');
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Fee record error: " . $e->getMessage());
    Response::error('Failed to record fee: ' . $e->getMessage(), 500);
}
?>
