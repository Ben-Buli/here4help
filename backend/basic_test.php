<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 檢查 Authorization 頭
$auth_found = false;
$auth_value = '';

// 檢查 $_SERVER 變數
if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
    $auth_found = true;
    $auth_value = substr($_SERVER['HTTP_AUTHORIZATION'], 0, 20) . '...';
}

// 檢查 getallheaders 函數
if (function_exists('getallheaders')) {
    $headers = getallheaders();
    if (isset($headers['Authorization'])) {
        $auth_found = true;
        $auth_value = substr($headers['Authorization'], 0, 20) . '...';
    }
}

// 構建響應
$response = [
    'success' => $auth_found,
    'message' => $auth_found ? 'Authorization header found' : 'No Authorization header',
    'timestamp' => date('Y-m-d H:i:s'),
    'auth_found' => $auth_found,
    'auth_value' => $auth_value,
    'server_vars' => array_keys($_SERVER),
    'php_version' => PHP_VERSION
];

if (!$auth_found) {
    http_response_code(401);
}

echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
?>
