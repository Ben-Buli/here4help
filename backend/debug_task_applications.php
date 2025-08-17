<?php
/**
 * 診斷特定任務的應徵記錄
 * 用於檢查為什麼 applications[] 為空
 */

require_once 'config/database.php';

try {
    echo "<h1>任務應徵記錄診斷</h1>\n";
    
    $db = Database::getInstance();
    echo "<p>✅ 數據庫連接成功</p>\n";
    
    // 檢查任務 ID
    $taskId = '292d1142-9b70-419b-8824-6f08a1490e68';
    echo "<h2>檢查任務: $taskId</h2>\n";
    
    // 1. 檢查任務是否存在
    echo "<h3>1. 檢查任務是否存在</h3>\n";
    $task = $db->fetch("SELECT * FROM tasks WHERE id = ?", [$taskId]);
    if ($task) {
        echo "<p>✅ 任務存在</p>\n";
        echo "<p>📋 任務信息:</p>\n";
        echo "<pre>" . print_r($task, true) . "</pre>\n";
    } else {
        echo "<p>❌ 任務不存在</p>\n";
        exit;
    }
    
    // 2. 檢查該任務的應徵記錄
    echo "<h3>2. 檢查該任務的應徵記錄</h3>\n";
    $applications = $db->fetchAll("SELECT * FROM task_applications WHERE task_id = ?", [$taskId]);
    echo "<p>📊 應徵記錄數量: " . count($applications) . "</p>\n";
    
    if (count($applications) > 0) {
        echo "<p>📋 應徵記錄:</p>\n";
        foreach ($applications as $i => $app) {
            echo "<h4>應徵記錄 " . ($i + 1) . ":</h4>\n";
            echo "<pre>" . print_r($app, true) . "</pre>\n";
        }
    } else {
        echo "<p>⚠️ 沒有找到應徵記錄</p>\n";
        
        // 檢查是否有其他任務有應徵記錄
        echo "<h4>檢查其他任務的應徵記錄:</h4>\n";
        $otherApps = $db->fetchAll("SELECT task_id, COUNT(*) as count FROM task_applications GROUP BY task_id LIMIT 5");
        if (count($otherApps) > 0) {
            echo "<p>📊 其他任務的應徵記錄:</p>\n";
            foreach ($otherApps as $other) {
                echo "<p>- 任務 {$other['task_id']}: {$other['count']} 個應徵</p>\n";
            }
        } else {
            echo "<p>❌ 整個 task_applications 表都沒有記錄</p>\n";
        }
    }
    
    // 3. 檢查 task_applications 表結構
    echo "<h3>3. 檢查 task_applications 表結構</h3>\n";
    try {
        $columns = $db->fetchAll("DESCRIBE task_applications");
        echo "<p>📋 表結構:</p>\n";
        echo "<table border='1'>\n";
        echo "<tr><th>欄位</th><th>類型</th><th>Null</th><th>Key</th><th>Default</th><th>Extra</th></tr>\n";
        
        foreach ($columns as $column) {
            echo "<tr>";
            echo "<td>{$column['Field']}</td>";
            echo "<td>{$column['Type']}</td>";
            echo "<td>{$column['Null']}</td>";
            echo "<td>{$column['Key']}</td>";
            echo "<td>{$column['Default']}</td>";
            echo "<td>{$column['Extra']}</td>";
            echo "</tr>\n";
        }
        echo "</table>\n";
        
    } catch (Exception $e) {
        echo "<p>❌ 無法讀取表結構: {$e->getMessage()}</p>\n";
    }
    
    // 4. 檢查是否有數據但查詢失敗
    echo "<h3>4. 測試原始查詢</h3>\n";
    try {
        $testSql = "
          SELECT
            ta.id                           AS application_id,
            ta.user_id,
            ta.status                       AS application_status,
            ta.cover_letter,
            ta.created_at,
            ta.updated_at,
            u.name                          AS applier_name,
            u.avatar_url                    AS applier_avatar,
            t.id                            AS task_id,
            t.creator_id,
            t.participant_id,
            ts.code                         AS task_status_code,
            ts.display_name                 AS task_status_display
          FROM task_applications AS ta
          JOIN tasks AS t ON t.id = ta.task_id
          LEFT JOIN task_statuses AS ts ON ts.id = t.status_id
          LEFT JOIN users AS u ON u.id = ta.user_id
          WHERE t.id = ?
        ";
        
        echo "<p>🔍 測試 SQL:</p>\n";
        echo "<pre>$testSql</pre>\n";
        
        $testResult = $db->fetchAll($testSql, [$taskId]);
        echo "<p>✅ 測試查詢成功，結果數量: " . count($testResult) . "</p>\n";
        
        if (count($testResult) > 0) {
            echo "<p>📋 測試查詢結果:</p>\n";
            echo "<pre>" . print_r($testResult[0], true) . "</pre>\n";
        }
        
    } catch (Exception $e) {
        echo "<p>❌ 測試查詢失敗: {$e->getMessage()}</p>\n";
        echo "<p>錯誤堆疊:</p>\n";
        echo "<pre>" . $e->getTraceAsString() . "</pre>\n";
    }
    
    // 5. 檢查相關表的數據
    echo "<h3>5. 檢查相關表數據</h3>\n";
    
    // 檢查 task_statuses
    try {
        $statuses = $db->fetchAll("SELECT * FROM task_statuses LIMIT 5");
        echo "<p>📊 task_statuses 表記錄數: " . count($statuses) . "</p>\n";
        if (count($statuses) > 0) {
            echo "<p>📋 狀態示例:</p>\n";
            echo "<pre>" . print_r($statuses[0], true) . "</pre>\n";
        }
    } catch (Exception $e) {
        echo "<p>❌ task_statuses 表查詢失敗: {$e->getMessage()}</p>\n";
    }
    
    // 檢查 users
    try {
        $users = $db->fetchAll("SELECT id, name, email FROM users LIMIT 3");
        echo "<p>📊 users 表記錄數: " . count($users) . "</p>\n";
        if (count($users) > 0) {
            echo "<p>📋 用戶示例:</p>\n";
            echo "<pre>" . print_r($users[0], true) . "</pre>\n";
        }
    } catch (Exception $e) {
        echo "<p>❌ users 表查詢失敗: {$e->getMessage()}</p>\n";
    }
    
    echo "<h2>診斷完成</h2>\n";
    
} catch (Exception $e) {
    echo "<h2>❌ 診斷失敗</h2>\n";
    echo "<p>錯誤信息: " . $e->getMessage() . "</p>\n";
    echo "<p>錯誤堆疊:</p>\n";
    echo "<pre>" . $e->getTraceAsString() . "</pre>\n";
}
?>
