<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 簡單的錯誤報告
error_reporting(E_ALL);
ini_set('display_errors', 1);

// 檢查 Authorization 頭
$auth_header = null;
$http_auth_env = null;

// 方法1：檢查 getallheaders()
if (function_exists('getallheaders')) {
    $headers = getallheaders();
    if (isset($headers['Authorization'])) {
        $auth_header = 'FOUND: ' . substr($headers['Authorization'], 0, 20) . '...';
    } else {
        $auth_header = 'NOT_FOUND';
    }
} else {
    $auth_header = 'getallheaders() function not available';
}

// 方法2：檢查環境變數
if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
    $http_auth_env = 'FOUND: ' . substr($_SERVER['HTTP_AUTHORIZATION'], 0, 20) . '...';
} else {
    $http_auth_env = 'NOT_SET';
}

// 方法3：檢查 $_SERVER 中的所有變數
$server_vars = [];
foreach ($_SERVER as $key => $value) {
    if (stripos($key, 'authorization') !== false) {
        $server_vars[$key] = 'FOUND: ' . substr($value, 0, 20) . '...';
    }
}

// 構建響應
$response = [
    'success' => true,
    'message' => 'Simple authorization test completed',
    'timestamp' => date('Y-m-d H:i:s'),
    'method' => $_SERVER['REQUEST_METHOD'],
    'url' => $_SERVER['REQUEST_URI'],
    'auth_header' => $auth_header,
    'http_auth_env' => $http_auth_env,
    'server_vars' => $server_vars,
    'all_headers' => function_exists('getallheaders') ? array_keys(getallheaders()) : ['getallheaders not available']
];

// 檢查是否有 Authorization
if ($auth_header === 'FOUND' || $http_auth_env === 'FOUND' || !empty($server_vars)) {
    $response['message'] = 'Authorization header received successfully';
    http_response_code(200);
} else {
    $response['success'] = false;
    $response['message'] = 'No Authorization header found';
    $response['error_code'] = 'AUTH_HEADER_MISSING';
    http_response_code(401);
}

echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
?>
