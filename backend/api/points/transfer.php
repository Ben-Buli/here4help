<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../config/php84_compatibility.php';

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';

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
    // 驗證 JWT - 使用標準的 $_SERVER 方式
    $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
    $token = $_GET['token'] ?? $_POST['token'] ?? null;
    
    if (!$token && !empty($auth_header) && preg_match('/Bearer\s+(.*)$/i', $auth_header, $matches)) {
        $token = $matches[1];
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
    $requiredFields = ['from_user_id', 'to_user_id', 'amount', 'task_id', 'transaction_type'];
    foreach ($requiredFields as $field) {
        if (!isset($input[$field]) || empty($input[$field])) {
            Response::badRequest("Missing required field: $field");
        }
    }
    
    $fromUserId = (int)$input['from_user_id'];
    $toUserId = (int)$input['to_user_id'];
    $amount = (int)$input['amount'];
    $taskId = $input['task_id']; // ✅ 保持字符串格式，因為 tasks.id 是 varchar(36)
    $transactionType = $input['transaction_type'];
    
    // 驗證金額
    if ($amount <= 0) {
        Response::badRequest('Amount must be greater than 0');
    }
    
    // 驗證用戶權限（只能轉移自己的點數）
    $authenticatedUserId = (int)($userData['user_id'] ?? $userData['id'] ?? 0);
    if ($fromUserId !== $authenticatedUserId) {
        Response::forbidden('You can only transfer your own points');
    }
    
    $db = Database::getInstance();
    
    // 開始事務
    $db->beginTransaction();
    
    try {
        // 檢查轉出用戶的餘額
        $fromUserSql = "SELECT points FROM users WHERE id = ?";
        $fromUser = $db->fetch($fromUserSql, [$fromUserId]);
        
        if (!$fromUser) {
            throw new Exception('From user not found');
        }
        
        if ($fromUser['points'] < $amount) {
            throw new Exception('Insufficient balance');
        }
        
        // 檢查轉入用戶是否存在
        $toUserSql = "SELECT id FROM users WHERE id = ?";
        $toUser = $db->fetch($toUserSql, [$toUserId]);
        
        if (!$toUser) {
            throw new Exception('To user not found');
        }
        
        // 檢查任務是否存在且狀態正確
        $taskSql = "SELECT id, status_id, creator_id, participant_id FROM tasks WHERE id = ?";
        $task = $db->fetch($taskSql, [$taskId]);
        
        if (!$task) {
            throw new Exception('Task not found');
        }
        
        // 更新轉出用戶的點數
        $updateFromUserSql = "UPDATE users SET points = points - ? WHERE id = ?";
        $db->query($updateFromUserSql, [$amount, $fromUserId]);
        
        // 更新轉入用戶的點數
        $updateToUserSql = "UPDATE users SET points = points + ? WHERE id = ?";
        $db->query($updateToUserSql, [$amount, $toUserId]);
        
        // 記錄交易
        $transactionSql = "INSERT INTO point_transactions (
            user_id, transaction_type, amount, description, related_task_id, status, created_at
        ) VALUES (?, ?, ?, ?, ?, 'completed', NOW())";
        
        // 記錄轉出交易
        $db->query($transactionSql, [
            $fromUserId,
            'spend', // 使用 enum 值：spend
            -$amount,
            "Payment for task ID: $taskId",
            $taskId
        ]);
        $outTransactionId = $db->lastInsertId();
        
        // 記錄轉入交易
        $db->query($transactionSql, [
            $toUserId,
            'earn', // 使用 enum 值：earn
            $amount,
            "Payment received for task ID: $taskId",
            $taskId
        ]);
        $inTransactionId = $db->lastInsertId();
        
        // 提交事務
        $db->commit();
        
        Response::success([
            'from_user_id' => $fromUserId,
            'to_user_id' => $toUserId,
            'amount' => $amount,
            'task_id' => $taskId,
            'transaction_type' => $transactionType,
            'out_transaction_id' => (int)$outTransactionId,
            'in_transaction_id' => (int)$inTransactionId
        ], 'Points transferred successfully');
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    Response::serverError('Transfer failed: ' . $e->getMessage());
}
?>
