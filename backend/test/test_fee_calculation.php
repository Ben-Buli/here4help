<?php
/**
 * 測試費率計算邏輯
 */

try {
    // 使用 MAMP socket 連接
    $dsn = "mysql:unix_socket=/Applications/MAMP/tmp/mysql/mysql.sock;dbname=hero4helpdemofhs_hero4help;charset=utf8mb4";
    $pdo = new PDO($dsn, 'root', 'root', [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    
    echo "Database connected successfully.\n\n";
    
    // 測試不同的任務金額
    $testAmounts = [100, 500, 1000, 2000, 5000];
    
    foreach ($testAmounts as $amount) {
        echo "=== Testing with amount: $amount ===\n";
        
        // 讀取手續費設定
        $feeRow = $pdo->query("SELECT rate FROM task_completion_points_fee_settings WHERE is_active = 1 ORDER BY id DESC LIMIT 1")->fetch();
        
        if ($feeRow && isset($feeRow['rate'])) {
            $feeRate = (float)$feeRow['rate'];
            $feeAmount = round($amount * $feeRate, 2);
            $netAmount = max(0.0, $amount - $feeAmount);
            
            echo "Fee Rate: " . number_format($feeRate * 100, 2) . "%\n";
            echo "Fee Amount: " . number_format($feeAmount, 2) . "\n";
            echo "Net Amount: " . number_format($netAmount, 2) . "\n";
            echo "Creator Pays: " . number_format($amount, 2) . "\n";
            echo "Participant Receives: " . number_format($netAmount, 2) . "\n";
            echo "Platform Fee: " . number_format($feeAmount, 2) . "\n\n";
        } else {
            echo "No fee settings found.\n\n";
        }
    }
    
    // 測試費率表查詢
    echo "=== Fee Settings Query Test ===\n";
    $stmt = $pdo->query("SELECT * FROM task_completion_points_fee_settings WHERE is_active = 1 ORDER BY id DESC LIMIT 1");
    $feeSettings = $stmt->fetch();
    
    if ($feeSettings) {
        echo "Active Fee Settings:\n";
        echo "ID: {$feeSettings['id']}\n";
        echo "Rate: " . number_format((float)$feeSettings['rate'] * 100, 2) . "%\n";
        echo "Description: {$feeSettings['description']}\n";
        echo "Active: " . ($feeSettings['is_active'] ? 'Yes' : 'No') . "\n";
        echo "Created: {$feeSettings['created_at']}\n";
    } else {
        echo "No active fee settings found.\n";
    }
    
    echo "\n✅ Fee calculation test completed successfully!\n";
    
} catch (Exception $e) {
    echo "❌ Test failed with exception: " . $e->getMessage() . "\n";
    echo "Stack trace:\n" . $e->getTraceAsString() . "\n";
}
?>
