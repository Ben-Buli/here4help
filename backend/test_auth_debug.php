<?php
require_once __DIR__ . '/utils/Response.php';

Response::setCorsHeaders();

// 調試：記錄所有收到的 headers
$headers = getallheaders();
error_log("🔍 [test_auth_debug.php] 收到的所有 headers: " . json_encode($headers));

// 檢查 Authorization header
$authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';
error_log("🔍 [test_auth_debug.php] Authorization header: '$authHeader'");

// 檢查 $_SERVER 變數
error_log("🔍 [test_auth_debug.php] HTTP_AUTHORIZATION: " . ($_SERVER['HTTP_AUTHORIZATION'] ?? 'NOT_SET'));
error_log("🔍 [test_auth_debug.php] HTTP_AUTHORIZATION (getallheaders): " . (getallheaders()['Authorization'] ?? 'NOT_SET'));

// 返回調試信息
Response::success([
    'headers_received' => $headers,
    'authorization_header' => $authHeader,
    'http_authorization' => $_SERVER['HTTP_AUTHORIZATION'] ?? 'NOT_SET',
    'server_vars' => [
        'REQUEST_METHOD' => $_SERVER['REQUEST_METHOD'] ?? 'NOT_SET',
        'CONTENT_TYPE' => $_SERVER['CONTENT_TYPE'] ?? 'NOT_SET',
        'HTTP_CONTENT_TYPE' => $_SERVER['HTTP_CONTENT_TYPE'] ?? 'NOT_SET',
    ]
], 'Auth debug info');
?>

