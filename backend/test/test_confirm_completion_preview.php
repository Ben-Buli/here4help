<?php
/**
 * 測試 confirm_completion 的 preview 功能
 */

// 模擬 HTTP 請求
$_SERVER['REQUEST_METHOD'] = 'POST';
$_SERVER['HTTP_AUTHORIZATION'] = 'Bearer test_token'; // 簡化測試

// 模擬 POST 數據
$input = [
    'task_id' => 'test_task_123',
    'preview' => 1
];

// 將輸入數據寫入 php://input
$inputData = json_encode($input);
file_put_contents('php://input', $inputData);

try {
    // 包含 confirm_completion.php
    ob_start();
    include __DIR__ . '/../api/tasks/confirm_completion.php';
    $output = ob_get_clean();
    
    echo "=== Test Result ===\n";
    echo $output;
    
    // 解析 JSON 響應
    $response = json_decode($output, true);
    
    if ($response && isset($response['success']) && $response['success']) {
        echo "\n✅ Preview test PASSED\n";
        echo "Fee Rate: " . ($response['data']['fee_rate'] ?? 'N/A') . "\n";
        echo "Fee Amount: " . ($response['data']['fee'] ?? 'N/A') . "\n";
        echo "Net Amount: " . ($response['data']['net'] ?? 'N/A') . "\n";
    } else {
        echo "\n❌ Preview test FAILED\n";
        echo "Error: " . ($response['message'] ?? 'Unknown error') . "\n";
    }
    
} catch (Exception $e) {
    echo "❌ Test failed with exception: " . $e->getMessage() . "\n";
}
?>
