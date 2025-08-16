<?php
header('Content-Type: application/json');

// 啟用錯誤報告
error_reporting(E_ALL);
ini_set('display_errors', 1);

// 記錄所有請求信息
$log = [
    'timestamp' => date('Y-m-d H:i:s'),
    'method' => $_SERVER['REQUEST_METHOD'],
    'url' => $_SERVER['REQUEST_URI'],
    'headers' => getallheaders(),
    'authorization_header' => null,
    'http_authorization_env' => null,
    'server_vars' => [
        'HTTP_AUTHORIZATION' => $_SERVER['HTTP_AUTHORIZATION'] ?? 'NOT_SET',
        'REDIRECT_HTTP_AUTHORIZATION' => $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? 'NOT_SET',
    ]
];

// 檢查 Authorization 頭
$headers = getallheaders();
if (isset($headers['Authorization'])) {
    $log['authorization_header'] = 'FOUND: ' . substr($headers['Authorization'], 0, 20) . '...';
} else {
    $log['authorization_header'] = 'NOT_FOUND';
}

// 檢查環境變數
if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
    $log['http_authorization_env'] = 'FOUND: ' . substr($_SERVER['HTTP_AUTHORIZATION'], 0, 20) . '...';
} else {
    $log['http_authorization_env'] = 'NOT_SET';
}

// 檢查其他可能的環境變數
$possible_auth_vars = [
    'HTTP_AUTHORIZATION',
    'REDIRECT_HTTP_AUTHORIZATION',
    'AUTHORIZATION',
    'HTTP_X_AUTHORIZATION'
];

foreach ($possible_auth_vars as $var) {
    if (isset($_SERVER[$var])) {
        $log['server_vars'][$var] = 'FOUND: ' . substr($_SERVER[$var], 0, 20) . '...';
    }
}

// 模擬 API 響應
$response = [
    'success' => true,
    'message' => 'Authorization test completed',
    'data' => $log,
    'test_token' => 'test_token_12345'
];

// 如果沒有 Authorization 頭，模擬錯誤
if ($log['authorization_header'] === 'NOT_FOUND' && $log['http_authorization_env'] === 'NOT_SET') {
    $response['success'] = false;
    $response['message'] = 'Authorization header required';
    $response['error_code'] = 'AUTH_HEADER_MISSING';
    http_response_code(401);
} else {
    $response['message'] = 'Authorization header received successfully';
    http_response_code(200);
}

echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
?>
