<?php
/**
 * API 診斷測試腳本
 * 用於檢查數據庫連接和基本查詢
 */

require_once __DIR__ . '/config/database.php';
require_once __DIR__ . '/utils/Response.php';

Response::setCorsHeaders();

try {
    echo "<h1>API 診斷測試</h1>\n";
    
    // 測試數據庫連接
    echo "<h2>1. 測試數據庫連接</h2>\n";
    $db = Database::getInstance();
    echo "✅ 數據庫連接成功\n";
    
    // 測試基本查詢
    echo "<h2>2. 測試基本查詢</h2>\n";
    
    // 檢查任務表
    $tasks = $db->fetchAll("SELECT COUNT(*) as count FROM tasks");
    echo "✅ 任務表查詢成功，總數: " . $tasks[0]['count'] . "\n";
    
    // 檢查任務狀態表
    $statuses = $db->fetchAll("SELECT COUNT(*) as count FROM task_statuses");
    echo "✅ 任務狀態表查詢成功，總數: " . $statuses[0]['count'] . "\n";
    
    // 檢查應徵表
    $applications = $db->fetchAll("SELECT COUNT(*) as count FROM task_applications");
    echo "✅ 應徵表查詢成功，總數: " . $applications[0]['count'] . "\n";
    
    // 檢查用戶表
    $users = $db->fetchAll("SELECT COUNT(*) as count FROM users");
    echo "✅ 用戶表查詢成功，總數: " . $users[0]['count'] . "\n";
    
    // 測試具體的應徵查詢
    echo "<h2>3. 測試應徵查詢</h2>\n";
    
    // 獲取第一個任務 ID
    $firstTask = $db->fetch("SELECT id FROM tasks LIMIT 1");
    if ($firstTask) {
        $taskId = $firstTask['id'];
        echo "🔍 測試任務 ID: $taskId\n";
        
        // 測試應徵查詢
        $sql = "
          SELECT
            ta.id          AS application_id,
            ta.user_id,
            ta.status      AS application_status,
            ta.cover_letter,
            ta.answers_json,
            ta.created_at,
            ta.updated_at,
            u.name         AS applier_name,
            u.avatar_url   AS applier_avatar,
            t.id           AS task_id,
            t.creator_id,
            t.participant_id,
            s.code         AS task_status_code,
            s.display_name AS task_status_display
          FROM task_applications ta
          JOIN tasks t ON t.id = ta.task_id
          LEFT JOIN task_statuses s ON s.id = t.status_id
          LEFT JOIN users u ON u.id = ta.user_id
          WHERE ta.task_id = ?
          ORDER BY ta.created_at DESC
          LIMIT 50 OFFSET 0
        ";
        
        $rows = $db->fetchAll($sql, [$taskId]);
        echo "✅ 應徵查詢成功，結果數量: " . count($rows) . "\n";
        
        if (count($rows) > 0) {
            echo "📋 第一個應徵記錄:\n";
            echo "<pre>" . print_r($rows[0], true) . "</pre>\n";
        }
    } else {
        echo "⚠️ 沒有找到任務數據\n";
    }
    
    echo "<h2>4. 診斷完成</h2>\n";
    echo "✅ 所有測試通過\n";
    
} catch (Exception $e) {
    echo "<h2>❌ 錯誤</h2>\n";
    echo "錯誤信息: " . $e->getMessage() . "\n";
    echo "錯誤堆疊: " . $e->getTraceAsString() . "\n";
}
?>
