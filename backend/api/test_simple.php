<?php
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
