<?php
/**
 * POST /api/points/request_topup.php
 * 用戶提交點數儲值申請
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
}

try {
    $db = Database::getInstance();
    
    // 獲取 JSON 數據
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        $input = $_POST; // 支援 form-data
    }
    
    $userId = $input['user_id'] ?? null;
    $amount = $input['amount'] ?? null;
    $bankAccountLast5 = $input['bank_account_last5'] ?? '';
    $note = $input['note'] ?? '';
    
    // 驗證必填欄位
    $errors = [];
    if (!$userId) {
        $errors['user_id'] = 'User ID is required';
    }
    if (!$amount || !is_numeric($amount) || $amount <= 0) {
        $errors['amount'] = 'Valid amount is required';
    }
    if (empty($bankAccountLast5) || !preg_match('/^\d{5}$/', $bankAccountLast5)) {
        $errors['bank_account_last5'] = 'Bank account last 5 digits required (numeric only)';
    }
    
    if (!empty($errors)) {
        Response::validationError($errors);
    }
    
    // 檢查用戶是否存在
    $user = $db->fetch("SELECT id, name, email FROM users WHERE id = ?", [$userId]);
    if (!$user) {
        Response::error('User not found', 404);
    }
    
    // 檢查是否有待審核的申請
    $pendingRequest = $db->fetch("
        SELECT id FROM user_point_reviews 
        WHERE user_id = ? AND status = 'pending'
    ", [$userId]);
    
    if ($pendingRequest) {
        Response::error('You already have a pending topup request. Please wait for approval.', 409);
    }
    
    // 建立點數儲值申請
    $reasonText = $note ? 
        "銀行匯款 - 帳號末五碼: {$bankAccountLast5} | 備註: {$note}" : 
        "銀行匯款 - 帳號末五碼: {$bankAccountLast5}";
        
    $sql = "INSERT INTO user_point_reviews (
        user_id, points, reason, status, created_at, updated_at
    ) VALUES (?, ?, ?, 'pending', NOW(), NOW())";
    
    $db->query($sql, [
        $userId,
        (int)$amount,
        $reasonText
    ]);
    
    $requestId = $db->lastInsertId();
    
    // 獲取剛建立的申請記錄
    $request = $db->fetch("
        SELECT 
            pr.id,
            pr.user_id,
            pr.points,
            pr.reason,
            pr.status,
            pr.created_at,
            u.name as user_name,
            u.email as user_email
        FROM user_point_reviews pr
        JOIN users u ON pr.user_id = u.id
        WHERE pr.id = ?
    ", [$requestId]);
    
    Response::success([
        'request_id' => $requestId,
        'message' => 'Point topup request submitted successfully',
        'request' => $request,
        'bank_info' => [
            'bank_name' => '台灣銀行',
            'account_number' => '123-456-789-012',
            'account_holder' => 'Here4Help Co., Ltd.',
            'note' => 'Please include your account last 5 digits in transfer memo'
        ]
    ], 'Point topup request created');
    
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>