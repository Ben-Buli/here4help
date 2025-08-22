<?php
require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../utils/Response.php';

// 確保環境變數已載入
EnvLoader::load();

Response::setCorsHeaders();

$headers = getallheaders();
error_log("🔍 [test_auth_debug.php] 收到的所有 headers: " . json_encode($headers));

$authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';
error_log("🔍 [test_auth_debug.php] Authorization header: '$authHeader'");

error_log("🔍 [test_auth_debug.php] HTTP_AUTHORIZATION: " . ($_SERVER['HTTP_AUTHORIZATION'] ?? 'NOT_SET'));
error_log("🔍 [test_auth_debug.php] HTTP_AUTHORIZATION (getallheaders): " . (getallheaders()['Authorization'] ?? 'NOT_SET'));

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
