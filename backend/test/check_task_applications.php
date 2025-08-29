<?php
require_once __DIR__ . '/../config/database.php';

$task_id = '6c8103c1-3642-46e7-a3a9-fc8b78d2e5bf';
$user_id = 2;

echo "=== 檢查任務應徵記錄 ===\n";
echo "Task ID: $task_id\n";
echo "User ID: $user_id\n\n";

$db = Database::getInstance();

// 檢查任務信息
$task = $db->fetch("SELECT * FROM tasks WHERE id = ?", [$task_id]);
echo "任務信息:\n";
if ($task) {
    echo "- ID: {$task['id']}\n";
    echo "- 標題: {$task['title']}\n";
    echo "- 狀態: {$task['status_id']}\n";
    echo "- 創建者: {$task['creator_id']}\n";
    echo "- 參與者: {$task['participant_id']}\n";
} else {
    echo "- 任務不存在\n";
}

echo "\n=== 應徵記錄 ===\n";
$applications = $db->fetchAll(
    "SELECT ta.*, u.name as user_name 
     FROM task_applications ta 
     LEFT JOIN users u ON ta.user_id = u.id 
     WHERE ta.task_id = ?",
    [$task_id]
);

if ($applications) {
    foreach ($applications as $app) {
        echo "- ID: {$app['id']}\n";
        echo "  用戶: {$app['user_name']} (ID: {$app['user_id']})\n";
        echo "  狀態: {$app['status']}\n";
        echo "  創建時間: {$app['created_at']}\n";
        echo "  更新時間: {$app['updated_at']}\n";
        echo "\n";
    }
} else {
    echo "- 沒有應徵記錄\n";
}

echo "\n=== 特定用戶的應徵記錄 ===\n";
$userApplications = $db->fetchAll(
    "SELECT * FROM task_applications WHERE task_id = ? AND user_id = ?",
    [$task_id, $user_id]
);

if ($userApplications) {
    foreach ($userApplications as $app) {
        echo "- ID: {$app['id']}\n";
        echo "  狀態: {$app['status']}\n";
        echo "  創建時間: {$app['created_at']}\n";
        echo "  更新時間: {$app['updated_at']}\n";
        echo "\n";
    }
} else {
    echo "- 該用戶沒有應徵記錄\n";
}
?>
