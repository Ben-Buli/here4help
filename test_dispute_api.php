<?php
/**
 * 任務爭議模組 API 測試腳本
 */

// 測試配置
$baseUrl = 'http://127.0.0.1:8888/here4help/backend/api';
$testToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoyLCJlbWFpbCI6Imx1aXNhQHRlc3QuY29tIiwibmFtZSI6Ikx1aXNhIEtpbSIsInBlcm1pc3Npb24iOjk5LCJpYXQiOjE3NTY4MTIyMDEsImV4cCI6MTc1NjgxNTgwMSwibmJmIjoxNzU2ODQzODQ4fQ.ONsPixxfqHgHy0utFX_7K5LhsxBC0SI3vLezgtxwcd4';

function makeRequest($url, $method = 'GET', $data = null, $token = null) {
    $ch = curl_init();
    
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 30);
    
    $headers = ['Content-Type: application/json'];
    if ($token) {
        $headers[] = 'Authorization: Bearer ' . $token;
    }
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    
    if ($method === 'POST') {
        curl_setopt($ch, CURLOPT_POST, true);
        if ($data) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        }
    } elseif ($method === 'PATCH') {
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PATCH');
        if ($data) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        }
    }
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    
    curl_close($ch);
    
    return [
        'http_code' => $httpCode,
        'response' => $response,
        'error' => $error
    ];
}

function testApi($name, $url, $method = 'GET', $data = null, $token = null) {
    echo "\n=== 測試: $name ===\n";
    echo "URL: $url\n";
    echo "Method: $method\n";
    
    if ($data) {
        echo "Data: " . json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n";
    }
    
    $result = makeRequest($url, $method, $data, $token);
    
    echo "HTTP Code: " . $result['http_code'] . "\n";
    
    if ($result['error']) {
        echo "CURL Error: " . $result['error'] . "\n";
    }
    
    if ($result['response']) {
        $decoded = json_decode($result['response'], true);
        if ($decoded) {
            echo "Response: " . json_encode($decoded, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n";
        } else {
            echo "Raw Response: " . $result['response'] . "\n";
        }
    }
    
    echo "Status: " . ($result['http_code'] >= 200 && $result['http_code'] < 300 ? '✅ SUCCESS' : '❌ FAILED') . "\n";
    echo str_repeat('-', 50) . "\n";
    
    return $result;
}

echo "🚀 任務爭議模組 API 測試開始\n";
echo "Base URL: $baseUrl\n";
echo "Test Token: " . substr($testToken, 0, 20) . "...\n";

// 1. 測試爭議檢查 API
testApi(
    '檢查爭議是否存在',
    $baseUrl . '/task-disputes/check.php?chat_room_id=test_room_123',
    'GET',
    null,
    $testToken
);

// 2. 測試爭議建立 API (這個可能會失敗，因為需要真實的任務和聊天室)
testApi(
    '建立爭議 (測試資料)',
    $baseUrl . '/task-disputes/create.php',
    'POST',
    [
        'task_id' => 'test_task_123',
        'task_dispute_chat_room_id' => 'test_room_123',
        'title' => 'Test Dispute Title',
        'description' => 'This is a test dispute description for API testing purposes.'
    ],
    $testToken
);

// 3. 測試管理員爭議列表 API (需要管理員 token)
testApi(
    '管理員爭議列表',
    $baseUrl . '/admin/task-disputes.php',
    'GET',
    null,
    $testToken
);

// 4. 測試管理員聊天室查看 API
testApi(
    '管理員聊天室查看',
    $baseUrl . '/admin/task-disputes/chat-room.php?dispute_id=1',
    'GET',
    null,
    $testToken
);

// 5. 測試管理員決策 API
testApi(
    '管理員決策',
    $baseUrl . '/admin/task-disputes/resolve.php?id=1',
    'PATCH',
    [
        'decision_result' => 'completed',
        'decision_note' => 'Test resolution note for API testing.'
    ],
    $testToken
);

echo "\n🏁 API 測試完成\n";
echo "注意: 某些測試可能會失敗，因為需要真實的資料庫資料和正確的 JWT token。\n";
echo "這些測試主要用於驗證 API 端點是否可訪問和基本功能是否正常。\n";
?>
