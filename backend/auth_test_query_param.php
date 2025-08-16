<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

// 處理 OPTIONS 預檢請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// 方法1：從查詢參數獲取 token
$token = $_GET['token'] ?? null;

// 方法2：從 POST 數據獲取 token
if (!$token && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    $token = $input['token'] ?? null;
}

// 方法3：從自定義頭獲取 token（如果有的話）
if (!$token) {
    $headers = getallheaders();
    if (isset($headers['X-Auth-Token'])) {
        $token = $headers['X-Auth-Token'];
    }
}

// 驗證 token
if (!$token || empty(trim($token))) {
    $response = [
        'success' => false,
        'message' => 'Token required (use ?token=YOUR_TOKEN or X-Auth-Token header)',
        'error_code' => 'TOKEN_MISSING',
        'timestamp' => date('Y-m-d H:i:s'),
        'usage' => [
            'query_param' => 'GET /auth_test_query_param.php?token=YOUR_TOKEN',
            'post_body' => 'POST with {"token": "YOUR_TOKEN"}',
            'custom_header' => 'X-Auth-Token: YOUR_TOKEN'
        ]
    ];
    
    http_response_code(401);
    echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    exit;
}

// Token 驗證通過
$response = [
    'success' => true,
    'message' => 'Token received successfully',
    'timestamp' => date('Y-m-d H:i:s'),
    'token_preview' => substr($token, 0, 20) . '...',
    'token_length' => strlen($token),
    'method' => $_SERVER['REQUEST_METHOD'],
    'url' => $_SERVER['REQUEST_URI'],
    'note' => 'This is a workaround for MAMP FastCGI Authorization header issue'
];

echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
?>
