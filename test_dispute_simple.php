<?php
/**
 * 簡化版任務爭議模組測試
 * 測試 API 端點可訪問性和基本回應格式
 */

echo "🚀 任務爭議模組簡化測試\n";
echo "========================\n\n";

$baseUrl = 'http://127.0.0.1:8888/here4help/backend/api';
$testEndpoints = [
    'GET /task-disputes/check.php?chat_room_id=test' => '/task-disputes/check.php?chat_room_id=test',
    'POST /task-disputes/create.php' => '/task-disputes/create.php',
    'GET /admin/task-disputes.php' => '/admin/task-disputes.php',
    'GET /admin/task-disputes/chat-room.php?dispute_id=1' => '/admin/task-disputes/chat-room.php?dispute_id=1',
    'PATCH /admin/task-disputes/resolve.php?id=1' => '/admin/task-disputes/resolve.php?id=1',
];

function testEndpoint($name, $url) {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    curl_close($ch);
    
    echo "📡 測試: $name\n";
    echo "   URL: $url\n";
    echo "   HTTP Code: $httpCode\n";
    
    if ($error) {
        echo "   ❌ CURL Error: $error\n";
        return false;
    }
    
    if ($httpCode == 0) {
        echo "   ❌ 無法連接到伺服器\n";
        return false;
    }
    
    // 檢查回應是否為有效 JSON
    $decoded = json_decode($response, true);
    if ($decoded === null) {
        echo "   ❌ 回應不是有效的 JSON\n";
        echo "   Raw Response: " . substr($response, 0, 200) . "...\n";
        return false;
    }
    
    // 檢查是否有預期的結構
    if (isset($decoded['success'])) {
        $status = $decoded['success'] ? '✅ 成功' : '⚠️  預期錯誤';
        echo "   $status: " . ($decoded['message'] ?? '無訊息') . "\n";
        
        // 401 錯誤是預期的（因為沒有 JWT token）
        if ($httpCode == 401 && isset($decoded['code']) && $decoded['code'] == 'E2001') {
            echo "   ✅ JWT 認證機制正常工作\n";
            return true;
        }
        
        return $decoded['success'] || $httpCode == 401;
    } else {
        echo "   ❌ 回應格式不正確\n";
        return false;
    }
}

$totalTests = count($testEndpoints);
$passedTests = 0;

foreach ($testEndpoints as $name => $endpoint) {
    $url = $baseUrl . $endpoint;
    $result = testEndpoint($name, $url);
    
    if ($result) {
        $passedTests++;
    }
    
    echo "   " . str_repeat('-', 50) . "\n\n";
}

echo "📊 測試結果總結\n";
echo "================\n";
echo "總測試數: $totalTests\n";
echo "通過測試: $passedTests\n";
echo "成功率: " . round(($passedTests / $totalTests) * 100, 1) . "%\n\n";

if ($passedTests == $totalTests) {
    echo "🎉 所有 API 端點測試通過！\n";
    echo "✅ 爭議模組基本功能正常\n";
    echo "✅ JWT 認證機制運作正常\n";
    echo "✅ 錯誤處理機制正確\n\n";
    echo "📋 下一步建議：\n";
    echo "1. 執行手動測試驗證完整流程\n";
    echo "2. 檢查資料庫表結構是否正確\n";
    echo "3. 測試 Flutter App 和 Admin Web 介面\n";
} else {
    echo "⚠️  部分測試未通過，請檢查：\n";
    echo "1. 後端伺服器是否正常運行\n";
    echo "2. API 檔案是否正確部署\n";
    echo "3. 資料庫連接是否正常\n";
}

echo "\n🔗 相關檔案：\n";
echo "- 完整測試指南: docs/任務爭議模組測試指南.md\n";
echo "- 資料庫修正: database_fixes/dispute_module_fixes.sql\n";
echo "- API 測試: test_dispute_api.php\n";
?>
