<?php
/**
 * GET /api/wallet/bank-accounts.php
 * 銀行帳戶管理API - 獲取啟用的官方銀行帳戶資訊
 */

require_once dirname(__DIR__, 2) . '/config/database.php'; // 因為 database.php 在 /backend/config/，要從 /backend/api/wallet 回到 /backend，需要往上兩層，再拼 /config/database.php 
require_once dirname(__DIR__, 2) . '/utils/response.php';
require_once dirname(__DIR__, 2) . '/utils/JWTManager.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::methodNotAllowed('Only GET method is allowed');
}

try {
    // 驗證 JWT
    $token = $_GET['token'] ?? null;
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
    
    $db = Database::getInstance();
    
    // 獲取啟用的銀行帳戶
    $activeAccountQuery = "
        SELECT id, bank_name, account_number, account_holder, 
               admin_id, created_at, updated_at
        FROM official_bank_accounts 
        WHERE is_active = 1 
        ORDER BY updated_at DESC 
        LIMIT 1
    ";
    
    $activeAccount = $db->fetch($activeAccountQuery);
    
    if (!$activeAccount) {
        // 如果沒有啟用的帳戶，返回空資訊
        Response::success([
            'has_active_account' => false,
            'active_account' => null,
            'default_info' => null
        ], 'No active bank account configured');
    }
    
    // 格式化帳號顯示（添加分隔符）
    $formattedAccountNumber = $activeAccount['account_number'];
    if (is_numeric($activeAccount['account_number']) && strlen($activeAccount['account_number']) >= 10) {
        // 如果是純數字且長度足夠，添加分隔符
        $accountNumber = $activeAccount['account_number'];
        $formattedAccountNumber = substr($accountNumber, 0, 3) . '-' . 
                                 substr($accountNumber, 3, 3) . '-' . 
                                 substr($accountNumber, 6, 3) . '-' . 
                                 substr($accountNumber, 9);
    }
    
    Response::success([
        'has_active_account' => true,
        'active_account' => [
            'id' => (int)$activeAccount['id'],
            'bank_name' => $activeAccount['bank_name'],
            'account_number' => $activeAccount['account_number'], // 原始帳號
            'account_number_formatted' => $formattedAccountNumber, // 格式化帳號
            'account_holder' => $activeAccount['account_holder'],
            'admin_id' => $activeAccount['admin_id'],
            'created_at' => $activeAccount['created_at'],
            'updated_at' => $activeAccount['updated_at']
        ],
        'copy_info' => [
            'bank_name' => $activeAccount['bank_name'],
            'account_number' => $activeAccount['account_number'],
            'account_holder' => $activeAccount['account_holder']
        ]
    ], 'Active bank account retrieved successfully');
    
} catch (Exception $e) {
    Response::serverError('Failed to retrieve bank account information: ' . $e->getMessage());
}
?>
