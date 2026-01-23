<?php
require_once __DIR__ . '/bootstrap.php';
// 載入 PHP 8.4 相容性配置

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

$headers = getallheaders();
$serverVars = [];

foreach ($_SERVER as $key => $value) {
    if (strpos($key, 'HTTP_') === 0) {
        $serverVars[$key] = $value;
    }
}

echo json_encode([
    'headers' => $headers,
    'server_vars' => $serverVars,
    'auth_header' => $headers['Authorization'] ?? 'NOT_FOUND',
    'http_authorization' => $_SERVER['HTTP_AUTHORIZATION'] ?? 'NOT_FOUND'
]);
