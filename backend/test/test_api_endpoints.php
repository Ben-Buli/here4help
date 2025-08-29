<?php
/**
 * 測試 API 端點
 */

require_once dirname(__DIR__, 1) . '/config/database.php';
require_once dirname(__DIR__, 1) . '/utils/response.php';
require_once dirname(__DIR__, 1) . '/utils/JWTManager.php';

header('Content-Type: application/json');

echo "=== API 端點測試 ===\n\n";

try {
    $db = Database::getInstance();
    
    // 獲取測試用戶
    $testUser = $db->fetch("SELECT id, name, email FROM users WHERE email = 'chris@test.com' LIMIT 1");
    if (!$testUser) {
        echo "❌ 找不到測試用戶\n";
        exit;
    }
    
    echo "測試用戶: {$testUser['name']} (ID: {$testUser['id']})\n\n";
    
    // 生成測試 JWT token
    $payload = [
        'user_id' => $testUser['id'],
        'email' => $testUser['email'],
        'name' => $testUser['name'],
        'permission' => 99,
        'iat' => time(),
        'exp' => time() + 3600,
        'nbf' => time()
    ];
    
    $token = JWTManager::generateToken($payload);
    echo "測試 Token: $token\n\n";
    
    // 測試 API 端點
    $baseUrl = 'http://localhost:8888/here4help/backend/api/wallet';
    
    echo "1. 測試 summary.php...\n";
    $summaryUrl = "$baseUrl/summary.php?token=$token";
    $summaryResponse = file_get_contents($summaryUrl);
    $summaryData = json_decode($summaryResponse, true);
    
    if ($summaryData && isset($summaryData['success']) && $summaryData['success']) {
        echo "✅ summary.php 正常\n";
        echo "   用戶點數: {$summaryData['data']['points_summary']['total_points']}\n";
    } else {
        echo "❌ summary.php 失敗: " . ($summaryData['message'] ?? 'Unknown error') . "\n";
    }
    
    echo "\n2. 測試 bank-accounts.php...\n";
    $bankUrl = "$baseUrl/bank-accounts.php?token=$token";
    $bankResponse = file_get_contents($bankUrl);
    $bankData = json_decode($bankResponse, true);
    
    if ($bankData && isset($bankData['success']) && $bankData['success']) {
        echo "✅ bank-accounts.php 正常\n";
        if ($bankData['data']['has_active_account']) {
            echo "   銀行名稱: {$bankData['data']['active_account']['bank_name']}\n";
            echo "   帳號: {$bankData['data']['active_account']['account_number']}\n";
        }
    } else {
        echo "❌ bank-accounts.php 失敗: " . ($bankData['message'] ?? 'Unknown error') . "\n";
    }
    
    echo "\n3. 測試 fee-settings.php...\n";
    $feeUrl = "$baseUrl/fee-settings.php?token=$token";
    $feeResponse = file_get_contents($feeUrl);
    $feeData = json_decode($feeResponse, true);
    
    if ($feeData && isset($feeData['success']) && $feeData['success']) {
        echo "✅ fee-settings.php 正常\n";
        echo "   手續費率: " . ($feeData['data']['rate'] * 100) . "%\n";
    } else {
        echo "❌ fee-settings.php 失敗: " . ($feeData['message'] ?? 'Unknown error') . "\n";
    }
    
    echo "\n=== 測試完成 ===\n";
    
} catch (Exception $e) {
    echo "❌ 測試失敗: " . $e->getMessage() . "\n";
}
?>
