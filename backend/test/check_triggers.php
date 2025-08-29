<?php
require_once __DIR__ . '/../config/database.php';

echo "=== 檢查數據庫觸發器 ===\n";

$db = Database::getInstance();

// 檢查所有觸發器
$triggers = $db->fetchAll("SHOW TRIGGERS");

if ($triggers) {
    echo "發現的觸發器:\n";
    foreach ($triggers as $trigger) {
        echo "- 觸發器: {$trigger['Trigger']}\n";
        echo "  表: {$trigger['Table']}\n";
        echo "  事件: {$trigger['Event']}\n";
        echo "  時機: {$trigger['Timing']}\n";
        echo "  語句: {$trigger['Statement']}\n";
        echo "\n";
    }
} else {
    echo "沒有發現觸發器\n";
}

// 特別檢查 task_applications 表的觸發器
echo "\n=== task_applications 表的觸發器 ===\n";
$taskAppTriggers = $db->fetchAll("SHOW TRIGGERS WHERE `Table` = 'task_applications'");

if ($taskAppTriggers) {
    foreach ($taskAppTriggers as $trigger) {
        echo "- 觸發器: {$trigger['Trigger']}\n";
        echo "  事件: {$trigger['Event']}\n";
        echo "  時機: {$trigger['Timing']}\n";
        echo "  語句: {$trigger['Statement']}\n";
        echo "\n";
    }
} else {
    echo "task_applications 表沒有觸發器\n";
}
?>
