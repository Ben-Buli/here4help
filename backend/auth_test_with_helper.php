<?php
require_once 'auth_helper.php';

// 使用輔助函數驗證 Authorization
if (!validateAuthorizationAndRespond()) {
    exit;
}

// 如果到這裡，說明 Authorization 驗證通過
$token = extractTokenFromHeader();

$response = [
    'success' => true,
    'message' => 'Authorization header received successfully',
    'timestamp' => date('Y-m-d H:i:s'),
    'token_preview' => substr($token, 0, 20) . '...',
    'token_length' => strlen($token),
    'method' => $_SERVER['REQUEST_METHOD'],
    'url' => $_SERVER['REQUEST_URI']
];

echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
?>
