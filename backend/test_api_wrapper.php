<?php
require_once 'api_wrapper.php';

// 測試認證
$userId = authenticateRequest();
if (!$userId) {
    exit; // 已自動返回錯誤響應
}

// 認證成功，返回用戶信息
$userData = [
    'user_id' => $userId,
    'message' => 'API wrapper test successful',
    'timestamp' => date('Y-m-d H:i:s'),
    'note' => 'This demonstrates the MAMP-compatible API wrapper'
];

returnSuccessResponse($userData, 'Authentication successful');
?>
