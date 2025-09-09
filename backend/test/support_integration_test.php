<?php
/**
 * 客服聊天室整合測試腳本
 * 
 * 執行所有客服相關的測試，確保整個流程正常運作
 */

echo "🚀 客服聊天室整合測試開始\n";
echo "測試時間: " . date('Y-m-d H:i:s') . "\n";
echo str_repeat('=', 60) . "\n\n";

$testResults = [];
$totalTests = 0;
$passedTests = 0;

// 測試 1: 資料庫功能測試
echo "🧪 執行測試 1: 資料庫功能測試\n";
$totalTests++;
$result1 = runTest(__DIR__ . '/support_database_test.php');
if ($result1) {
    echo "✅ 測試 1 通過\n";
    $passedTests++;
} else {
    echo "❌ 測試 1 失敗\n";
}
$testResults['database_functions'] = $result1;
echo "\n";

// 測試結果總結
echo str_repeat('=', 60) . "\n";
echo "📊 測試結果總結\n";
echo str_repeat('=', 60) . "\n";
echo "總測試數: $totalTests\n";
echo "通過測試: $passedTests\n";
echo "失敗測試: " . ($totalTests - $passedTests) . "\n";
echo "成功率: " . round(($passedTests / $totalTests) * 100, 2) . "%\n\n";

// 詳細結果
echo "📋 詳細測試結果:\n";
foreach ($testResults as $testName => $result) {
    $status = $result ? '✅ 通過' : '❌ 失敗';
    echo "  - $testName: $status\n";
}
echo "\n";

if ($passedTests === $totalTests) {
    echo "🎉 所有測試通過！客服聊天室功能已準備就緒\n";
    exit(0);
} else {
    echo "⚠️ 部分測試失敗，請檢查相關功能\n";
    exit(1);
}

/**
 * 執行測試腳本
 */
function runTest($testFile) {
    if (!file_exists($testFile)) {
        echo "❌ 測試文件不存在: $testFile\n";
        return false;
    }
    
    // 捕獲輸出
    ob_start();
    $exitCode = 0;
    
    try {
        // 執行測試腳本
        include $testFile;
    } catch (Exception $e) {
        echo "❌ 測試執行異常: " . $e->getMessage() . "\n";
        $exitCode = 1;
    }
    
    $output = ob_get_clean();
    
    // 顯示測試輸出
    echo $output;
    
    // 檢查是否有錯誤輸出
    if (strpos($output, '❌') !== false || $exitCode !== 0) {
        return false;
    }
    
    return true;
}
?>
