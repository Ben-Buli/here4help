<?php
/**
 * 檢查數據庫表結構
 * 用於診斷數據庫問題
 */

require_once __DIR__ . '/config/database.php';

try {
    echo "<h1>數據庫表結構檢查</h1>\n";
    
    $db = Database::getInstance();
    echo "<p>✅ 數據庫連接成功</p>\n";
    
    // 檢查所有表
    $tables = ['tasks', 'task_applications', 'task_statuses', 'users'];
    
    foreach ($tables as $table) {
        echo "<h2>檢查表: $table</h2>\n";
        
        try {
            // 檢查表是否存在
            $result = $db->fetch("SHOW TABLES LIKE '$table'");
            if ($result) {
                echo "<p>✅ 表 $table 存在</p>\n";
                
                // 檢查表結構
                $columns = $db->fetchAll("DESCRIBE $table");
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
                
                // 檢查記錄數量
                $count = $db->fetch("SELECT COUNT(*) as count FROM $table");
                echo "<p>📊 記錄數量: {$count['count']}</p>\n";
                
                // 如果是關鍵表，顯示一些示例數據
                if ($table === 'tasks' && $count['count'] > 0) {
                    $sample = $db->fetch("SELECT id, title, creator_id FROM $table LIMIT 1");
                    echo "<p>📋 示例數據:</p>\n";
                    echo "<pre>" . print_r($sample, true) . "</pre>\n";
                }
                
            } else {
                echo "<p>❌ 表 $table 不存在</p>\n";
            }
            
        } catch (Exception $e) {
            echo "<p>❌ 檢查表 $table 失敗: {$e->getMessage()}</p>\n";
        }
        
        echo "<hr>\n";
    }
    
    echo "<h2>檢查完成</h2>\n";
    
} catch (Exception $e) {
    echo "<h2>❌ 錯誤</h2>\n";
    echo "<p>錯誤信息: " . $e->getMessage() . "</p>\n";
    echo "<p>錯誤堆疊:</p>\n";
    echo "<pre>" . $e->getTraceAsString() . "</pre>\n";
}
?>
