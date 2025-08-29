<?php
/**
 * POST /api/points/request_topup.php
 * 用戶提交點數儲值申請
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
}

try {
    // 先驗證 JWT，缺 Token 應回 401 而不是 500
    $jwt = JWTManager::validateRequest();
    if (!$jwt['valid']) {
        Response::unauthorized($jwt['message'] ?? 'Unauthorized');
    }
    $tokenUserId = (int)($jwt['payload']['user_id'] ?? 0);

    $db = Database::getInstance();
    
    // 獲取 JSON 數據
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        $input = $_POST; // 支援 form-data
    }
    
    // user_id 以 Token 為準，避免偽造
    $userId = $tokenUserId ?: ($input['user_id'] ?? null);
    $amount = (int)($input['amount'] ?? null);
    $bankAccountLast5 = $input['bank_account_last5'] ?? '';
    
    // 驗證必填欄位
    $errors = [];
    if (!$userId) {
        $errors['user_id'] = 'User ID is required';
    }
    // 檢查金額是否為正整數，且小於 100,000
    if (!$amount || !is_numeric($amount) || $amount <= 0) {
        $errors['amount'] = 'Valid amount is required.';
    } else if ((int)$amount > 99999) {
        $errors['amount'] = 'The amount must be less than 100,000.';
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
    
     /// #region 檢查是否重複申請中（末五碼、金額重複）
     $isPendingDuplicateRequest = $db->fetch(
        "SELECT id FROM point_deposit_requests 
        WHERE user_id = ? AND bank_account_last5 = ? AND amount_points = ? AND status = 'pending'", [$userId, $bankAccountLast5, $amount]);
    if ($isPendingDuplicateRequest) {
        Response::error('The same amount and bank account last 5 digits already have a pending topup request. Please wait for approval.', 409);
    }
    // #endregion   

    // #region 檢查是否有待審核的申請
    // 檢查是否有待審核的申請
    // $pendingRequest = $db->fetch("
    //     SELECT id FROM point_deposit_requests 
    //     WHERE user_id = ? AND status = 'pending'
    // ", [$userId]);
    
    // // 檢查是否有待審核的申請
    // if ($pendingRequest) {
    //     Response::error('You already have a pending topup request. Please wait for approval.', 409);
    // }
   // #endregion

    // 新增申請記錄
    $sql = "INSERT INTO point_deposit_requests (
        user_id, amount_points, bank_account_last5, status
    ) VALUES (?, ?, ?, 'pending')";
    
    $db->query($sql, [
        $userId,
        (int)$amount,
        $bankAccountLast5
    ]);
    
    $requestId = $db->lastInsertId();
    
    // 獲取剛建立的申請記錄
    $request = $db->fetch("
        SELECT 
            pdr.id,
            pdr.user_id,
            pdr.amount_points,
            pdr.bank_account_last5,
            pdr.approver_reply_description,
            pdr.status,
            pdr.created_at,
            u.name as user_name,
            u.email as user_email
        FROM point_deposit_requests pdr
        JOIN users u ON pdr.user_id = u.id
        WHERE pdr.id = ?
    ", [$requestId]);
    
    // Fetch official bank account info
    $bankInfo = $db->fetch("SELECT bank_name, account_number, account_holder FROM official_bank_accounts WHERE is_active = 1 LIMIT 1");
    Response::success([
        'request_id' => $requestId,
        'message' => 'Point topup request submitted successfully!',
        'request' => $request,
        'bank_info' => $bankInfo ?: null
    ], 'Point topup request created');
    
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>