<?php
require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../utils/JWTManager.php';

echo "=== 簡化個人資料 API 測試 ===\n\n";

// 生成測試 JWT token
$jwtManager = new JWTManager();
$testToken = $jwtManager->generateToken(['user_id' => 1]);

echo "測試 Token: " . substr($testToken, 0, 50) . "...\n\n";

// 測試 URL
$url = 'http://localhost:8888/here4help/backend/api/account/profile.php?token=' . urlencode($testToken);

echo "請求 URL: $url\n\n";

// 使用 cURL 進行測試
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'Authorization: Bearer ' . $testToken
]);
curl_setopt($ch, CURLOPT_VERBOSE, true);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$error = curl_error($ch);
curl_close($ch);

echo "HTTP 狀態碼: $httpCode\n";
if ($error) {
    echo "cURL 錯誤: $error\n";
}
echo "回應內容: $response\n";

if ($response) {
    $data = json_decode($response, true);
    if ($data) {
        echo "解析後的 JSON:\n";
        print_r($data);
    } else {
        echo "JSON 解析失敗\n";
    }
}
?>
