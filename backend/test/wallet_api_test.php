<?php
/**
 * 錢包API測試腳本
 * 測試修復後的錢包相關API端點
 */

require_once __DIR__ . '/../utils/JWTManager.php';

// 測試用戶ID
$testUserId = 1;

try {
    // 生成測試Token
    $testToken = JWTManager::generateToken(['user_id' => $testUserId]);
    echo "Generated test token: " . substr($testToken, 0, 50) . "...\n\n";
    
    // 測試API端點
    $baseUrl = 'http://localhost:8888/here4help/backend/api';
    
    $endpoints = [
        'wallet/summary.php' => '錢包統計',
        'wallet/fee-settings.php' => '手續費設定',
        'wallet/bank-accounts.php' => '銀行帳戶',
        'wallet/transactions.php' => '交易記錄',
        'fees/summary.php' => '手續費統計'
    ];
    
    foreach ($endpoints as $endpoint => $description) {
        echo "測試 $description ($endpoint):\n";
        
        $url = "$baseUrl/$endpoint";
        $context = stream_context_create([
            'http' => [
                'method' => 'GET',
                'header' => [
                    "Authorization: Bearer $testToken",
                    "Content-Type: application/json"
                ]
            ]
        ]);
        
        $response = @file_get_contents($url, false, $context);
        
        if ($response === false) {
            echo "❌ 無法連接到API\n";
        } else {
            $data = json_decode($response, true);
            if (json_last_error() === JSON_ERROR_NONE) {
                if (isset($data['success']) && $data['success']) {
                    echo "✅ API正常回應\n";
                } else {
                    echo "⚠️  API回應錯誤: " . ($data['message'] ?? 'Unknown error') . "\n";
                }
            } else {
                echo "❌ JSON解析錯誤: " . json_last_error_msg() . "\n";
                echo "原始回應: " . substr($response, 0, 200) . "...\n";
            }
        }
        echo "\n";
    }
    
} catch (Exception $e) {
    echo "測試失敗: " . $e->getMessage() . "\n";
}
?>
