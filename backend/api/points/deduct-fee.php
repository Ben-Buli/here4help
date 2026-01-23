<?php
require_once __DIR__ . '/bootstrap.php';
// 載入 PHP 8.4 相容性配置

/**
 * POST /api/points/deduct-fee.php
 * 扣除手續費AP
 */

require_once dirname(__DIR__, 2) . '/config/database.php'; 

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::methodNotAllowed('Only POST method is allowed');
}

try {
    // 驗證 JWT
    $token = $_GET['token'] ?? $_POST['token'] ?? null;
    if (!$token) {
        $headers = getallheaders();
        $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';
        if (preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
            $token = $matches[1];
        }
    }
    
    if (!$token) {
        Response::unauthorized('No token provided');
    }
    
    $userData = JWTManager::validateToken($token);
    
    if (!$userData) {
        Response::unauthorized('Invalid token');
    }
    
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        Response::badRequest('Invalid JSON input');
    }
    
    // 驗證必要參數
    $requiredFields = ['user_id', 'amount', 'task_id', 'fee_rate', 'transaction_type'];
    foreach ($requiredFields as $field) {
        if (!isset($input[$field]) || empty($input[$field])) {
            Response::badRequest("Missing required field: $field");
        }
    }
    
    $userId = (int)$input['user_id'];
    $amount = (int)$input['amount'];
    $taskId = $input['task_id']; // ✅ 保持字符串格式，因為 tasks.id 是 varchar(36)
    $feeRate = (float)$input['fee_rate'];
    $transactionType = $input['transaction_type'];
    
    // 驗證金額
    if ($amount <= 0) {
        Response::badRequest('Amount must be greater than 0');
    }
    
    // 驗證用戶權限（只能扣除自己的手續費）
    if ($userId !== (int)$userData['id']) {
        Response::forbidden('You can only deduct fees from your own account');
    }
    
    $db = Database::getInstance();
    
    // 開始事務
    $db->beginTransaction();
    
    try {
        // 檢查用戶的餘額
        $userSql = "SELECT points FROM users WHERE id = ?";
        $user = $db->fetch($userSql, [$userId]);
        
        if (!$user) {
            throw new Exception('User not found');
        }
        
        if ($user['points'] < $amount) {
            throw new Exception('Insufficient balance for fee deduction');
        }
        
        // 檢查任務是否存在
        $taskSql = "SELECT id FROM tasks WHERE id = ?";
        $task = $db->fetch($taskSql, [$taskId]);
        
        if (!$task) {
            throw new Exception('Task not found');
        }
        
        // 扣除用戶點數
        $updateUserSql = "UPDATE users SET points = points - ? WHERE id = ?";
        $db->query($updateUserSql, [$amount, $userId]);
        
        // 記錄交易
        $transactionSql = "INSERT INTO point_transactions (
            user_id, transaction_type, amount, description, related_task_id, status, created_at
        ) VALUES (?, ?, ?, ?, ?, 'completed', NOW())";
        
        $db->query($transactionSql, [
            $userId,
            'fee', // 使用 enum 值：fee
            -$amount,
            "Task completion fee (${(float)$feeRate * 100}%)",
            $taskId
        ]);
        
        // 提交事務
        $db->commit();
        
        Response::success([
            'user_id' => $userId,
            'amount' => $amount,
            'task_id' => $taskId,
            'fee_rate' => $feeRate,
            'transaction_type' => $transactionType
        ], 'Fee deducted successfully');
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    Response::serverError('Fee deduction failed: ' . $e->getMessage());
}
?>
