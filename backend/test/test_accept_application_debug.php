<?php
// 測試 accept application API 的詳細錯誤信息
error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "=== Accept Application API 測試 ===\n";

// 模擬前端請求
$url = 'http://localhost:8888/here4help/backend/api/tasks/applications/accept.php';

// 使用已知的測試數據
$data = [
    'task_id' => '6c8103c1-3642-46e7-a3a9-fc8b78d2e5bf',
    'application_id' => '123164',  // 使用現有的應徵ID
    'poster_id' => '1'
];

// 使用有效的 JWT token（從前端日誌中獲取）
$token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxLCJlbWFpbCI6Im1pY2hhZWxAdGVzdC5jb20iLCJuYW1lIjoiTWljaGFlbCIsInBlcm1pc3Npb24iOjk5LCJpYXQiOjE3NTYyNjYyMDAsImV4cCI6MTc1NjI2OTgwMCwibmJmIjoxNzU2MjY2MjAwfQ.Ta6y6YsXYzTJ_bmKtpy0vonuLOuA5MX48gu5DSIvGBU';

$headers = [
    'Content-Type: application/json',
    'Authorization: Bearer ' . $token
];

echo "請求 URL: $url\n";
echo "請求數據: " . json_encode($data, JSON_PRETTY_PRINT) . "\n";
echo "Token: " . substr($token, 0, 50) . "...\n\n";

// 發送請求
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_VERBOSE, true);
curl_setopt($ch, CURLOPT_HEADER, true);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$error = curl_error($ch);
curl_close($ch);

echo "HTTP 狀態碼: $httpCode\n";
if ($error) {
    echo "CURL 錯誤: $error\n";
}

echo "完整響應:\n$response\n";

// 分離頭部和主體
$headerSize = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
$header = substr($response, 0, $headerSize);
$body = substr($response, $headerSize);

echo "\n=== 響應頭部 ===\n$header\n";
echo "\n=== 響應主體 ===\n$body\n";

// 嘗試解析 JSON
$jsonData = json_decode($body, true);
if ($jsonData) {
    echo "\n=== 解析的 JSON ===\n";
    echo json_encode($jsonData, JSON_PRETTY_PRINT) . "\n";
} else {
    echo "\n=== JSON 解析失敗 ===\n";
    echo "原始響應: $body\n";
}
?>
