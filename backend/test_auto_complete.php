<?php
/**
 * 測試用自動完成任務腳本
 * 用於測試 pending confirmation 任務的自動完成功能
 * 
 * 使用方法：
 * php backend/test_auto_complete.php
 */

require_once __DIR__ . '/config/database.php';

echo "🧪 測試用自動完成任務腳本\n";
echo "================================\n\n";

try {
    $db = Database::getInstance()->getConnection();
    
    // 1. 查詢所有 pending confirmation 任務
    echo "📋 查詢所有 pending confirmation 任務...\n";
    $allPendingSql = "
        SELECT 
            t.id,
            t.title,
            t.creator_id,
            t.participant_id,
            t.updated_at,
            TIMESTAMPDIFF(SECOND, t.updated_at, NOW()) as seconds_pending,
            DATEDIFF(NOW(), t.updated_at) as days_pending
        FROM tasks t
        JOIN task_statuses ts ON t.status_id = ts.id
        WHERE ts.code = 'pending_confirmation'
        ORDER BY t.updated_at DESC
    ";
    
    $stmt = $db->prepare($allPendingSql);
    $stmt->execute();
    $allPendingTasks = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($allPendingTasks)) {
        echo "ℹ️  沒有找到 pending confirmation 狀態的任務\n\n";
    } else {
        echo "找到 " . count($allPendingTasks) . " 個 pending confirmation 任務：\n";
        foreach ($allPendingTasks as $task) {
            echo "  📝 任務 {$task['id']}: {$task['title']}\n";
            echo "     更新時間: {$task['updated_at']}\n";
            echo "     等待時間: {$task['days_pending']} 天 ({$task['seconds_pending']} 秒)\n";
            echo "     創建者: {$task['creator_id']}, 執行者: {$task['participant_id']}\n\n";
        }
    }
    
    // 2. 查詢超過 10 秒的任務（測試用）
    echo "⏰ 查詢超過 10 秒的任務（測試模式）...\n";
    $testSql = "
        SELECT 
            t.id,
            t.title,
            t.creator_id,
            t.participant_id,
            t.updated_at,
            TIMESTAMPDIFF(SECOND, t.updated_at, NOW()) as seconds_pending
        FROM tasks t
        JOIN task_statuses ts ON t.status_id = ts.id
        WHERE ts.code = 'pending_confirmation'
        AND TIMESTAMPDIFF(SECOND, t.updated_at, NOW()) >= 10
    ";
    
    $testStmt = $db->prepare($testSql);
    $testStmt->execute();
    $testTasks = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($testTasks)) {
        echo "ℹ️  沒有找到超過 10 秒的任務\n\n";
    } else {
        echo "找到 " . count($testTasks) . " 個超過 10 秒的任務：\n";
        foreach ($testTasks as $task) {
            echo "  ⚡ 任務 {$task['id']}: {$task['title']} (等待 {$task['seconds_pending']} 秒)\n";
        }
        echo "\n";
    }
    
    // 3. 查詢超過 7 天的任務（正式模式）
    echo "📅 查詢超過 7 天的任務（正式模式）...\n";
    $prodSql = "
        SELECT 
            t.id,
            t.title,
            t.creator_id,
            t.participant_id,
            t.updated_at,
            DATEDIFF(NOW(), t.updated_at) as days_pending
        FROM tasks t
        JOIN task_statuses ts ON t.status_id = ts.id
        WHERE ts.code = 'pending_confirmation'
        AND DATEDIFF(NOW(), t.updated_at) >= 7
    ";
    
    $prodStmt = $db->prepare($prodSql);
    $prodStmt->execute();
    $prodTasks = $prodStmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($prodTasks)) {
        echo "ℹ️  沒有找到超過 7 天的任務\n\n";
    } else {
        echo "找到 " . count($prodTasks) . " 個超過 7 天的任務：\n";
        foreach ($prodTasks as $task) {
            echo "  📆 任務 {$task['id']}: {$task['title']} (等待 {$task['days_pending']} 天)\n";
        }
        echo "\n";
    }
    
    // 4. 檢查 completed 狀態是否存在
    echo "🔍 檢查任務狀態配置...\n";
    $statusSql = "SELECT id, code, display_name FROM task_statuses WHERE code IN ('pending_confirmation', 'completed')";
    $statusStmt = $db->prepare($statusSql);
    $statusStmt->execute();
    $statuses = $statusStmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($statuses as $status) {
        echo "  ✅ 狀態 {$status['id']}: {$status['code']} ({$status['display_name']})\n";
    }
    echo "\n";
    
    // 5. 提供測試建議
    echo "💡 測試建議：\n";
    echo "1. 如果要測試自動完成，請執行：\n";
    echo "   php cron/auto_complete_tasks.php\n\n";
    echo "2. 如果要手動完成任務，請使用管理員帳號在前端點擊 'Time Up' 按鈕\n\n";
    echo "3. 如果要創建測試任務：\n";
    echo "   - 創建新任務並接受應徵\n";
    echo "   - 將任務標記為 'Mark as Completed'\n";
    echo "   - 任務狀態會變為 'pending_confirmation'\n\n";
    
    echo "✅ 測試腳本執行完成\n";
    
} catch (Exception $e) {
    echo "❌ 錯誤: " . $e->getMessage() . "\n";
    exit(1);
}
?>
