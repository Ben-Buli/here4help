<?php
/**
 * 檢查測試數據
 */

try {
    // 使用 MAMP socket 連接
    $dsn = "mysql:unix_socket=/Applications/MAMP/tmp/mysql/mysql.sock;dbname=hero4helpdemofhs_hero4help;charset=utf8mb4";
    $pdo = new PDO($dsn, 'root', 'root', [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    
    echo "Database connected successfully.\n\n";
    
    // 檢查任務數據
    echo "=== Tasks ===\n";
    $stmt = $pdo->query("SELECT id, title, reward_point, status_id, creator_id, participant_id FROM tasks LIMIT 5");
    $tasks = $stmt->fetchAll();
    
    if (empty($tasks)) {
        echo "No tasks found.\n";
    } else {
        foreach ($tasks as $task) {
            echo "ID: {$task['id']}, Title: {$task['title']}, Reward: {$task['reward_point']}, Status: {$task['status_id']}\n";
        }
    }
    
    // 檢查任務狀態
    echo "\n=== Task Statuses ===\n";
    $stmt = $pdo->query("SELECT id, code, display_name FROM task_statuses");
    $statuses = $stmt->fetchAll();
    
    foreach ($statuses as $status) {
        echo "ID: {$status['id']}, Code: {$status['code']}, Name: {$status['display_name']}\n";
    }
    
    // 檢查用戶數據
    echo "\n=== Users ===\n";
    $stmt = $pdo->query("SELECT id, username, name, points FROM users LIMIT 5");
    $users = $stmt->fetchAll();
    
    if (empty($users)) {
        echo "No users found.\n";
    } else {
        foreach ($users as $user) {
            echo "ID: {$user['id']}, Username: {$user['username']}, Name: {$user['name']}, Points: {$user['points']}\n";
        }
    }
    
    // 檢查費率設定
    echo "\n=== Fee Settings ===\n";
    $stmt = $pdo->query("SELECT id, rate, description, is_active FROM task_completion_points_fee_settings WHERE is_active = 1");
    $feeSettings = $stmt->fetchAll();
    
    foreach ($feeSettings as $setting) {
        echo "ID: {$setting['id']}, Rate: " . number_format((float)$setting['rate'] * 100, 2) . "%, Active: {$setting['is_active']}\n";
    }
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    exit(1);
}
?>
