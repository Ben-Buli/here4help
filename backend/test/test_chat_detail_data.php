<?php
/**
 * 測試聊天室詳細數據 API
 */

try {
    // 使用 MAMP socket 連接
    $dsn = "mysql:unix_socket=/Applications/MAMP/tmp/mysql/mysql.sock;dbname=hero4helpdemofhs_hero4help;charset=utf8mb4";
    $pdo = new PDO($dsn, 'root', 'root', [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    
    echo "Database connected successfully.\n\n";
    
    // 檢查聊天室數據
    echo "=== Chat Rooms Data ===\n";
    $stmt = $pdo->query("
        SELECT cr.id, cr.task_id, cr.creator_id, cr.participant_id, cr.type, 
               t.title, t.status_id, ts.code as status_code, ts.display_name
        FROM chat_rooms cr
        LEFT JOIN tasks t ON cr.task_id = t.id
        LEFT JOIN task_statuses ts ON t.status_id = ts.id
        LIMIT 5
    ");
    $chatRooms = $stmt->fetchAll();
    
    echo "Sample chat rooms:\n";
    foreach ($chatRooms as $room) {
        echo "  - Room ID: {$room['id']}\n";
        echo "    Task: {$room['task_id']} ({$room['title']})\n";
        echo "    Type: {$room['type']}\n";
        echo "    Creator: {$room['creator_id']}, Participant: {$room['participant_id']}\n";
        echo "    Status: {$room['status_code']} ({$room['display_name']})\n";
        echo "\n";
    }
    
    // 檢查用戶數據
    echo "=== Users Data ===\n";
    $stmt = $pdo->query("SELECT id, name, points FROM users LIMIT 5");
    $users = $stmt->fetchAll();
    
    echo "Sample users:\n";
    foreach ($users as $user) {
        echo "  - ID: {$user['id']}, Name: {$user['name']}, Points: {$user['points']}\n";
    }
    
    // 檢查任務數據
    echo "\n=== Tasks Data ===\n";
    $stmt = $pdo->query("
        SELECT t.id, t.title, t.reward_point, t.creator_id, t.participant_id, 
               ts.code as status_code, ts.display_name
        FROM tasks t
        LEFT JOIN task_statuses ts ON t.status_id = ts.id
        LIMIT 5
    ");
    $tasks = $stmt->fetchAll();
    
    echo "Sample tasks:\n";
    foreach ($tasks as $task) {
        echo "  - ID: {$task['id']}\n";
        echo "    Title: {$task['title']}\n";
        echo "    Reward: {$task['reward_point']}\n";
        echo "    Creator: {$task['creator_id']}, Participant: {$task['participant_id']}\n";
        echo "    Status: {$task['status_code']} ({$task['display_name']})\n";
        echo "\n";
    }
    
    // 測試建議
    echo "=== Testing Recommendations ===\n";
    
    if (!empty($chatRooms)) {
        $testRoom = $chatRooms[0];
        echo "✅ For Chat Detail testing:\n";
        echo "   Use room ID: {$testRoom['id']}\n";
        echo "   Task ID: {$testRoom['task_id']}\n";
        echo "   Task Title: {$testRoom['title']}\n";
        echo "   Room Type: {$testRoom['type']}\n";
        echo "   Creator: {$testRoom['creator_id']}, Participant: {$testRoom['participant_id']}\n\n";
    }
    
    echo "=== API Endpoint Test ===\n";
    echo "To test the chat detail API, use:\n";
    echo "GET /backend/api/chat/get_chat_detail_data.php?room_id=<room_id>\n";
    echo "Headers: Authorization: Bearer <token>\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    exit(1);
}
?>
