<?php
/**
 * 尋找適合測試的任務
 */

try {
    // 使用 MAMP socket 連接
    $dsn = "mysql:unix_socket=/Applications/MAMP/tmp/mysql/mysql.sock;dbname=hero4helpdemofhs_hero4help;charset=utf8mb4";
    $pdo = new PDO($dsn, 'root', 'root', [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    
    echo "Database connected successfully.\n\n";
    
    // 1. 尋找 pending_confirmation 狀態的任務（用於測試確認完成）
    echo "=== Tasks for Confirm/Disagree Testing ===\n";
    $stmt = $pdo->query("
        SELECT t.id, t.title, t.reward_point, t.creator_id, t.participant_id, ts.code as status_code, ts.display_name
        FROM tasks t 
        LEFT JOIN task_statuses ts ON t.status_id = ts.id 
        WHERE ts.code = 'pending_confirmation' 
        LIMIT 5
    ");
    $pendingTasks = $stmt->fetchAll();
    
    if (empty($pendingTasks)) {
        echo "❌ No pending_confirmation tasks found.\n";
        echo "You need to create a task and move it to pending_confirmation status.\n\n";
    } else {
        echo "✅ Found " . count($pendingTasks) . " pending_confirmation tasks:\n";
        foreach ($pendingTasks as $task) {
            echo "  - ID: {$task['id']}\n";
            echo "    Title: {$task['title']}\n";
            echo "    Reward: {$task['reward_point']} points\n";
            echo "    Creator: {$task['creator_id']}\n";
            echo "    Participant: {$task['participant_id']}\n";
            echo "    Status: {$task['status_code']} ({$task['display_name']})\n";
            echo "\n";
        }
    }
    
    // 2. 尋找 open 狀態且有應徵者的任務（用於測試接受應徵）
    echo "=== Tasks for Accept Application Testing ===\n";
    $stmt = $pdo->query("
        SELECT t.id, t.title, t.reward_point, t.creator_id, ts.code as status_code, ts.display_name
        FROM tasks t 
        LEFT JOIN task_statuses ts ON t.status_id = ts.id 
        WHERE ts.code = 'open' 
        LIMIT 5
    ");
    $openTasks = $stmt->fetchAll();
    
    if (empty($openTasks)) {
        echo "❌ No open tasks found.\n";
        echo "You need to create open tasks for testing.\n\n";
    } else {
        echo "✅ Found " . count($openTasks) . " open tasks:\n";
        foreach ($openTasks as $task) {
            echo "  - ID: {$task['id']}\n";
            echo "    Title: {$task['title']}\n";
            echo "    Reward: {$task['reward_point']} points\n";
            echo "    Creator: {$task['creator_id']}\n";
            echo "    Status: {$task['status_code']} ({$task['display_name']})\n";
            echo "\n";
        }
    }
    
    // 3. 檢查用戶點數餘額
    echo "=== User Points Balance ===\n";
    $stmt = $pdo->query("SELECT id, name, points FROM users LIMIT 5");
    $users = $stmt->fetchAll();
    
    echo "Sample users:\n";
    foreach ($users as $user) {
        echo "  - ID: {$user['id']}, Name: {$user['name']}, Points: {$user['points']}\n";
    }
    
    // 4. 檢查聊天室
    echo "\n=== Chat Rooms ===\n";
    $stmt = $pdo->query("
        SELECT cr.id, cr.task_id, cr.creator_id, cr.participant_id, cr.type, t.title
        FROM chat_rooms cr
        LEFT JOIN tasks t ON cr.task_id = t.id
        LIMIT 5
    ");
    $chatRooms = $stmt->fetchAll();
    
    echo "Sample chat rooms:\n";
    foreach ($chatRooms as $room) {
        echo "  - Room ID: {$room['id']}\n";
        echo "    Task: {$room['task_id']} ({$room['title']})\n";
        echo "    Type: {$room['type']}\n";
        echo "    Creator: {$room['creator_id']}, Participant: {$room['participant_id']}\n";
        echo "\n";
    }
    
    // 5. 測試建議
    echo "=== Testing Recommendations ===\n";
    
    if (!empty($pendingTasks)) {
        $testTask = $pendingTasks[0];
        echo "✅ For Confirm/Disagree testing:\n";
        echo "   Use task ID: {$testTask['id']}\n";
        echo "   Login as creator ID: {$testTask['creator_id']}\n";
        echo "   Expected reward: {$testTask['reward_point']} points\n";
        echo "   Expected fee: " . round($testTask['reward_point'] * 0.02, 2) . " points (2%)\n";
        echo "   Expected net: " . round($testTask['reward_point'] * 0.98, 2) . " points\n\n";
    }
    
    if (!empty($openTasks)) {
        $testTask = $openTasks[0];
        echo "✅ For Accept Application testing:\n";
        echo "   Use task ID: {$testTask['id']}\n";
        echo "   Login as creator ID: {$testTask['creator_id']}\n";
        echo "   Task title: {$testTask['title']}\n\n";
    }
    
    echo "=== Next Steps ===\n";
    echo "1. Start Flutter app: flutter run -d chrome\n";
    echo "2. Login with the suggested user ID\n";
    echo "3. Navigate to the chat detail page for the suggested task\n";
    echo "4. Test the Action Bar buttons\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    exit(1);
}
?>
