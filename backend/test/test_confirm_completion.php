<?php
/**
 * 測試 confirm_completion 功能
 */

try {
    // 使用 MAMP socket 連接
    $dsn = "mysql:unix_socket=/Applications/MAMP/tmp/mysql/mysql.sock;dbname=hero4helpdemofhs_hero4help;charset=utf8mb4";
    $pdo = new PDO($dsn, 'root', 'root', [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    
    echo "Database connected successfully.\n\n";
    
    // 找到一個 pending_confirmation 狀態的任務
    $stmt = $pdo->query("
        SELECT t.id, t.title, t.reward_point, t.creator_id, t.participant_id, ts.code as status_code
        FROM tasks t 
        LEFT JOIN task_statuses ts ON t.status_id = ts.id 
        WHERE ts.code = 'pending_confirmation' 
        LIMIT 1
    ");
    $task = $stmt->fetch();
    
    if (!$task) {
        echo "No pending_confirmation tasks found. Creating test task...\n";
        
        // 創建一個測試任務
        $testTaskId = 'test_task_' . time();
        $creatorId = 1; // 假設用戶ID為1
        $participantId = 2; // 假設接案者ID為2
        
        $stmt = $pdo->prepare("
            INSERT INTO tasks (id, title, description, reward_point, location, task_date, creator_id, participant_id, status_id, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
        ");
        
        $stmt->execute([
            $testTaskId,
            'Test Task for Action Bar Logic',
            'This is a test task for testing the action bar logic',
            1000, // 1000 點獎勵
            'Test Location',
            '2025-01-17',
            $creatorId,
            $participantId,
            3 // pending_confirmation status_id
        ]);
        
        echo "Test task created with ID: $testTaskId\n";
        $task = [
            'id' => $testTaskId,
            'title' => 'Test Task for Action Bar Logic',
            'reward_point' => 1000,
            'creator_id' => $creatorId,
            'participant_id' => $participantId,
            'status_code' => 'pending_confirmation'
        ];
    }
    
    echo "Testing with task:\n";
    echo "ID: {$task['id']}\n";
    echo "Title: {$task['title']}\n";
    echo "Reward: {$task['reward_point']}\n";
    echo "Status: {$task['status_code']}\n";
    echo "Creator: {$task['creator_id']}\n";
    echo "Participant: {$task['participant_id']}\n\n";
    
    // 測試 preview 功能
    echo "=== Testing Preview Function ===\n";
    
    // 模擬 HTTP 請求
    $_SERVER['REQUEST_METHOD'] = 'POST';
    $_SERVER['HTTP_AUTHORIZATION'] = 'Bearer test_token';
    
    // 模擬 POST 數據
    $input = [
        'task_id' => $task['id'],
        'preview' => 1
    ];
    
    // 將輸入數據寫入 php://input
    $inputData = json_encode($input);
    file_put_contents('php://input', $inputData);
    
    // 包含 confirm_completion.php
    ob_start();
    include __DIR__ . '/../api/tasks/confirm_completion.php';
    $output = ob_get_clean();
    
    echo "Raw Response:\n$output\n\n";
    
    // 解析 JSON 響應
    $response = json_decode($output, true);
    
    if ($response && isset($response['success']) && $response['success']) {
        echo "✅ Preview test PASSED\n";
        $data = $response['data'];
        echo "Fee Rate: " . number_format((float)$data['fee_rate'] * 100, 2) . "%\n";
        echo "Fee Amount: " . number_format((float)$data['fee'], 2) . "\n";
        echo "Net Amount: " . number_format((float)$data['net'], 2) . "\n";
        echo "Preview: " . ($data['preview'] ? 'true' : 'false') . "\n";
        
        // 驗證計算
        $expectedFee = $task['reward_point'] * 0.02; // 2% 費率
        $expectedNet = $task['reward_point'] - $expectedFee;
        
        echo "\nExpected calculations:\n";
        echo "Expected Fee: " . number_format($expectedFee, 2) . "\n";
        echo "Expected Net: " . number_format($expectedNet, 2) . "\n";
        
        if (abs($data['fee'] - $expectedFee) < 0.01 && abs($data['net'] - $expectedNet) < 0.01) {
            echo "✅ Calculations are correct!\n";
        } else {
            echo "❌ Calculations are incorrect!\n";
        }
        
    } else {
        echo "❌ Preview test FAILED\n";
        echo "Error: " . ($response['message'] ?? 'Unknown error') . "\n";
    }
    
} catch (Exception $e) {
    echo "❌ Test failed with exception: " . $e->getMessage() . "\n";
    echo "Stack trace:\n" . $e->getTraceAsString() . "\n";
}
?>
