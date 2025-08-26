<?php
/**
 * 檢查資料庫結構是否符合規格文件要求
 * 根據 docs/優先執行/聊天室模組_整合規格＿now_todo.md
 */

require_once __DIR__ . '/config/database.php';

try {
    echo "<h1>資料庫結構規格檢查</h1>\n";
    echo "<p>根據規格文件：docs/優先執行/聊天室模組_整合規格＿now_todo.md</p>\n";
    
    $db = Database::getInstance();
    echo "<p>✅ 數據庫連接成功</p>\n";
    
    // 檢查要點列表
    $checks = [
        [
            'name' => 'tasks.participant_id → participant_id',
            'sql' => "SHOW COLUMNS FROM tasks LIKE 'participant_id'",
            'expected' => 'participant_id 欄位存在',
            'critical' => true
        ],
        [
            'name' => 'tasks.participant_id 已移除',
            'sql' => "SHOW COLUMNS FROM tasks LIKE 'participant_id'",
            'expected' => 'participant_id 欄位不存在',
            'critical' => true
        ],
        [
            'name' => 'task_applications.status ENUM',
            'sql' => "SHOW COLUMNS FROM task_applications LIKE 'status'",
            'expected' => 'status 欄位為 ENUM("applied","accepted","rejected","pending","completed","cancelled","dispute", "withdrawn")',
            'critical' => true
        ],
        [
            'name' => 'task_statuses 表存在',
            'sql' => "SHOW TABLES LIKE 'task_statuses'",
            'expected' => 'task_statuses 表存在',
            'critical' => true
        ],
        [
            'name' => 'chat_reads 表存在',
            'sql' => "SHOW TABLES LIKE 'chat_reads'",
            'expected' => 'chat_reads 表存在',
            'critical' => false
        ],
        [
            'name' => 'task_status_logs 表存在',
            'sql' => "SHOW TABLES LIKE 'task_status_logs'",
            'expected' => 'task_status_logs 表存在',
            'critical' => false
        ],
        [
            'name' => 'task_ratings 表有 tasker_id',
            'sql' => "SHOW COLUMNS FROM task_ratings LIKE 'tasker_id'",
            'expected' => 'task_ratings.tasker_id 欄位存在',
            'critical' => false
        ]
    ];
    
    $results = [];
    
    foreach ($checks as $check) {
        echo "<h2>檢查: {$check['name']}</h2>\n";
        
        try {
            $result = $db->fetch($check['sql']);
            
            if ($result) {
                if ($check['name'] === 'tasks.participant_id 已移除') {
                    echo "<p>❌ 問題：participant_id 欄位仍然存在</p>\n";
                    $results[] = ['name' => $check['name'], 'status' => 'FAIL', 'critical' => $check['critical']];
                } else {
                    echo "<p>✅ 通過：{$check['expected']}</p>\n";
                    $results[] = ['name' => $check['name'], 'status' => 'PASS', 'critical' => $check['critical']];
                }
            } else {
                if ($check['name'] === 'tasks.participant_id 已移除') {
                    echo "<p>✅ 通過：participant_id 欄位已移除</p>\n";
                    $results[] = ['name' => $check['name'], 'status' => 'PASS', 'critical' => $check['critical']];
                } else {
                    echo "<p>❌ 失敗：{$check['expected']}</p>\n";
                    $results[] = ['name' => $check['name'], 'status' => 'FAIL', 'critical' => $check['critical']];
                }
            }
            
            // 顯示詳細信息
            if ($result && $check['name'] === 'task_applications.status ENUM') {
                echo "<p>📋 欄位詳細信息:</p>\n";
                echo "<pre>" . print_r($result, true) . "</pre>\n";
            }
            
        } catch (Exception $e) {
            echo "<p>❌ 檢查失敗: {$e->getMessage()}</p>\n";
            $results[] = ['name' => $check['name'], 'status' => 'ERROR', 'critical' => $check['critical']];
        }
        
        echo "<hr>\n";
    }
    
    // 總結
    echo "<h2>檢查總結</h2>\n";
    
    $passCount = count(array_filter($results, fn($r) => $r['status'] === 'PASS'));
    $failCount = count(array_filter($results, fn($r) => $r['status'] === 'FAIL'));
    $errorCount = count(array_filter($results, fn($r) => $r['status'] === 'ERROR'));
    $criticalFails = count(array_filter($results, fn($r) => $r['status'] === 'FAIL' && $r['critical']));
    
    echo "<p>✅ 通過: $passCount</p>\n";
    echo "<p>❌ 失敗: $failCount</p>\n";
    echo "<p>⚠️ 錯誤: $errorCount</p>\n";
    
    if ($criticalFails > 0) {
        echo "<p><strong>🚨 關鍵問題: $criticalFails 個關鍵檢查失敗</strong></p>\n";
        echo "<p>這些問題會導致 API 無法正常工作</p>\n";
    }
    
    if ($failCount === 0 && $errorCount === 0) {
        echo "<p><strong>🎉 所有檢查通過！資料庫結構符合規格文件要求</strong></p>\n";
    }
    
    // 顯示失敗的項目
    if ($failCount > 0) {
        echo "<h3>失敗的檢查項目:</h3>\n";
        foreach ($results as $result) {
            if ($result['status'] === 'FAIL') {
                $critical = $result['critical'] ? ' (關鍵)' : '';
                echo "<p>❌ {$result['name']}$critical</p>\n";
            }
        }
    }
    
} catch (Exception $e) {
    echo "<h2>❌ 檢查失敗</h2>\n";
    echo "<p>錯誤信息: " . $e->getMessage() . "</p>\n";
    echo "<p>錯誤堆疊:</p>\n";
    echo "<pre>" . $e->getTraceAsString() . "</pre>\n";
}
?>
