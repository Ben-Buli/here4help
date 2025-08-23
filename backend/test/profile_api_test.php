<?php
require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../utils/JWTManager.php';

/**
 * 個人資料 API 測試腳本
 */

echo "=== 個人資料 API 測試 ===\n\n";

// 測試配置
$baseUrl = 'http://localhost:8888/here4help';
$testUserId = 1; // 請確保這個用戶存在

// 生成測試 JWT token
$jwtManager = new JWTManager();
$testToken = $jwtManager->generateToken(['user_id' => $testUserId]);

echo "測試 Token: " . substr($testToken, 0, 20) . "...\n\n";

/**
 * 測試 GET /api/account/profile
 */
function testGetProfile($baseUrl, $token) {
    echo "--- 測試獲取個人資料 ---\n";
    
    $url = $baseUrl . '/backend/api/account/profile.php?token=' . urlencode($token);
    
    $context = stream_context_create([
        'http' => [
            'method' => 'GET',
            'header' => [
                'Content-Type: application/json',
                'Authorization: Bearer ' . $token
            ]
        ]
    ]);
    
    $response = file_get_contents($url, false, $context);
    
    if ($response === false) {
        echo "❌ 請求失敗\n";
        return false;
    }
    
    $data = json_decode($response, true);
    
    if ($data['success'] ?? false) {
        echo "✅ 獲取個人資料成功\n";
        echo "用戶 ID: " . ($data['data']['id'] ?? 'N/A') . "\n";
        echo "用戶名稱: " . ($data['data']['name'] ?? 'N/A') . "\n";
        echo "Email: " . ($data['data']['email'] ?? 'N/A') . "\n";
        echo "頭像 URL: " . ($data['data']['avatar_url'] ?? 'N/A') . "\n";
        return $data['data'];
    } else {
        echo "❌ 獲取個人資料失敗: " . ($data['message'] ?? 'Unknown error') . "\n";
        return false;
    }
}

/**
 * 測試 PUT /api/account/profile
 */
function testUpdateProfile($baseUrl, $token) {
    echo "\n--- 測試更新個人資料 ---\n";
    
    $url = $baseUrl . '/backend/api/account/profile.php?token=' . urlencode($token);
    
    $updateData = [
        'nickname' => 'Test User ' . time(),
        'about_me' => 'Updated at ' . date('Y-m-d H:i:s'),
        'country' => 'Taiwan'
    ];
    
    $context = stream_context_create([
        'http' => [
            'method' => 'PUT',
            'header' => [
                'Content-Type: application/json',
                'Authorization: Bearer ' . $token
            ],
            'content' => json_encode($updateData)
        ]
    ]);
    
    $response = file_get_contents($url, false, $context);
    
    if ($response === false) {
        echo "❌ 更新請求失敗\n";
        return false;
    }
    
    $data = json_decode($response, true);
    
    if ($data['success'] ?? false) {
        echo "✅ 更新個人資料成功\n";
        echo "更新後暱稱: " . ($data['data']['nickname'] ?? 'N/A') . "\n";
        echo "更新後國家: " . ($data['data']['country'] ?? 'N/A') . "\n";
        echo "更新後關於我: " . ($data['data']['about_me'] ?? 'N/A') . "\n";
        return true;
    } else {
        echo "❌ 更新個人資料失敗: " . ($data['message'] ?? 'Unknown error') . "\n";
        return false;
    }
}

/**
 * 測試資料驗證
 */
function testValidation($baseUrl, $token) {
    echo "\n--- 測試資料驗證 ---\n";
    
    $url = $baseUrl . '/backend/api/account/profile.php?token=' . urlencode($token);
    
    // 測試無效的 email 格式
    $invalidData = [
        'phone' => 'invalid-phone-format-with-letters',
        'date_of_birth' => 'invalid-date-format',
        'gender' => 'InvalidGender'
    ];
    
    $context = stream_context_create([
        'http' => [
            'method' => 'PUT',
            'header' => [
                'Content-Type: application/json',
                'Authorization: Bearer ' . $token
            ],
            'content' => json_encode($invalidData)
        ]
    ]);
    
    $response = file_get_contents($url, false, $context);
    
    if ($response === false) {
        echo "❌ 驗證測試請求失敗\n";
        return false;
    }
    
    $data = json_decode($response, true);
    
    if (!($data['success'] ?? true)) {
        echo "✅ 資料驗證正常工作 - 拒絕無效資料\n";
        echo "錯誤訊息: " . ($data['message'] ?? 'N/A') . "\n";
        return true;
    } else {
        echo "❌ 資料驗證失敗 - 接受了無效資料\n";
        return false;
    }
}

/**
 * 測試權限控制
 */
function testUnauthorized($baseUrl) {
    echo "\n--- 測試未授權訪問 ---\n";
    
    $url = $baseUrl . '/backend/api/account/profile.php';
    
    $context = stream_context_create([
        'http' => [
            'method' => 'GET',
            'header' => [
                'Content-Type: application/json'
            ]
        ]
    ]);
    
    $response = file_get_contents($url, false, $context);
    
    if ($response === false) {
        echo "✅ 未授權訪問被正確拒絕\n";
        return true;
    }
    
    $data = json_decode($response, true);
    
    if (!($data['success'] ?? true)) {
        echo "✅ 未授權訪問被正確拒絕\n";
        echo "錯誤訊息: " . ($data['message'] ?? 'N/A') . "\n";
        return true;
    } else {
        echo "❌ 未授權訪問未被拒絕\n";
        return false;
    }
}

// 執行測試
$results = [];

$results['get_profile'] = testGetProfile($baseUrl, $testToken);
$results['update_profile'] = testUpdateProfile($baseUrl, $testToken);
$results['validation'] = testValidation($baseUrl, $testToken);
$results['unauthorized'] = testUnauthorized($baseUrl);

// 測試結果總結
echo "\n=== 測試結果總結 ===\n";
$passed = 0;
$total = count($results);

foreach ($results as $test => $result) {
    $status = $result ? '✅ PASS' : '❌ FAIL';
    echo "$test: $status\n";
    if ($result) $passed++;
}

echo "\n總計: $passed/$total 測試通過\n";

if ($passed === $total) {
    echo "🎉 所有測試通過！個人資料 API 功能正常\n";
} else {
    echo "⚠️  有測試失敗，請檢查 API 實作\n";
}
?>
