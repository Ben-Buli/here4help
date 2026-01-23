<?php
require_once __DIR__ . '/bootstrap.php';
/**
 * Ping API 端點
 * 用於檢查後端服務是否正常運作
 * 
 * 訪問方式：
 * GET /backend/api/ping
 * 
 * 回應：
 * { "pong": true }
 */

// 載入 PHP 8.4 相容性配置

// 設置 CORS 頭
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

// 處理 OPTIONS 預檢請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// 只允許 GET 請求
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode([
        'error' => 'Method Not Allowed',
        'message' => 'Only GET method is allowed for this endpoint'
    ]);
    exit;
}

// 返回 pong 回應
http_response_code(200);
echo json_encode([
    'pong' => true
]);
?>
