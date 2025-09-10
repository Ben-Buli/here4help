<?php
/**
 * 測試管理員 API 端點
 */

// 設置錯誤報告
error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "<h1>管理員 API 測試</h1>";

// 測試 API 端點列表
$apis = [
    'Tasks API' => '/api/admin/tasks.php',
    'Task Disputes API' => '/api/admin/task-disputes.php',
    'Support Chat Rooms API' => '/api/admin/support-chat-rooms.php',
    'Task Statuses API' => '/api/tasks/statuses.php'
];

$baseUrl = 'http://localhost:8080';

foreach ($apis as $name => $endpoint) {
    echo "<h2>測試 {$name}</h2>";
    
    $url = $baseUrl . $endpoint;
    
    // 使用 cURL 測試 API
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        'Authorization: Bearer test_token' // 假的 token，用於測試
    ]);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    echo "<p><strong>URL:</strong> {$url}</p>";
    echo "<p><strong>HTTP Status:</strong> {$httpCode}</p>";
    
    if ($response) {
        $data = json_decode($response, true);
        if ($data) {
            echo "<p><strong>Response:</strong></p>";
            echo "<pre>" . json_encode($data, JSON_PRETTY_PRINT) . "</pre>";
        } else {
            echo "<p><strong>Raw Response:</strong></p>";
            echo "<pre>" . htmlspecialchars($response) . "</pre>";
        }
    } else {
        echo "<p><strong>Error:</strong> No response</p>";
    }
    
    echo "<hr>";
}

echo "<h2>檔案存在性檢查</h2>";

$files = [
    '/api/admin/tasks.php',
    '/api/admin/task-disputes.php', 
    '/api/admin/support-chat-rooms.php',
    '/api/admin/support/claim-issue.php',
    '/api/admin/support/update-status.php'
];

foreach ($files as $file) {
    $fullPath = __DIR__ . $file;
    $exists = file_exists($fullPath);
    echo "<p>{$file}: " . ($exists ? '✅ 存在' : '❌ 不存在') . "</p>";
}
?>
