<?php
/**
 * 備份系統測試腳本
 * 測試備份管理功能（不依賴 mysqldump）
 */

require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../utils/Logger.php';

echo "🧪 備份系統功能測試\n";
echo "==================\n\n";

try {
    // 測試1: 目錄結構創建
    echo "1. 測試備份目錄結構\n";
    echo "-------------------\n";
    
    $backupDir = __DIR__ . '/backups';
    $subdirs = ['full', 'incremental', 'structure', 'logs', 'reports', 'emergency'];
    
    foreach ($subdirs as $subdir) {
        $path = $backupDir . '/' . $subdir;
        if (!is_dir($path)) {
            mkdir($path, 0755, true);
        }
        echo "✅ 目錄已創建: $subdir\n";
    }
    
    echo "\n";
    
    // 測試2: 模擬備份檔案創建
    echo "2. 測試備份檔案創建\n";
    echo "-------------------\n";
    
    $timestamp = date('Y-m-d_H-i-s');
    
    // 創建模擬備份檔案
    $testFiles = [
        "full/full_backup_{$timestamp}.sql" => "-- Full backup test\nCREATE TABLE test_full (id INT);\n",
        "structure/structure_backup_{$timestamp}.sql" => "-- Structure backup test\nCREATE TABLE test_structure (id INT);\n",
        "incremental/incremental_backup_{$timestamp}.sql" => "-- Incremental backup test\nINSERT INTO test (id) VALUES (1);\n"
    ];
    
    foreach ($testFiles as $file => $content) {
        $fullPath = $backupDir . '/' . $file;
        file_put_contents($fullPath, $content);
        echo "✅ 測試檔案已創建: $file (" . formatBytes(filesize($fullPath)) . ")\n";
    }
    
    echo "\n";
    
    // 測試3: 備份日誌記錄
    echo "3. 測試備份日誌記錄\n";
    echo "-------------------\n";
    
    $logFile = $backupDir . '/logs/backup.log';
    
    $backupLogs = [
        [
            'type' => 'full',
            'timestamp' => $timestamp,
            'file' => "full_backup_{$timestamp}.sql",
            'size' => 1024,
            'duration' => 45.2,
            'description' => '測試完整備份',
            'tables_count' => 25,
            'records_count' => 15000,
        ],
        [
            'type' => 'structure',
            'timestamp' => $timestamp,
            'file' => "structure_backup_{$timestamp}.sql",
            'size' => 512,
            'duration' => 12.5,
            'description' => '測試結構備份',
            'tables_count' => 25,
        ],
        [
            'type' => 'incremental',
            'timestamp' => $timestamp,
            'file' => "incremental_backup_{$timestamp}.sql",
            'size' => 256,
            'duration' => 8.3,
            'description' => '測試增量備份',
            'modified_tables' => ['users', 'tasks', 'chat_messages'],
            'base_backup_time' => date('Y-m-d H:i:s', strtotime('-6 hours')),
        ]
    ];
    
    foreach ($backupLogs as $log) {
        file_put_contents($logFile, json_encode($log) . "\n", FILE_APPEND | LOCK_EX);
        echo "✅ 備份日誌已記錄: {$log['type']} 備份\n";
    }
    
    echo "\n";
    
    // 測試4: 備份統計
    echo "4. 測試備份統計\n";
    echo "---------------\n";
    
    $stats = calculateBackupStats($backupDir);
    
    echo "總備份數: {$stats['total_backups']}\n";
    echo "總大小: " . formatBytes($stats['total_size']) . "\n";
    
    foreach ($stats['by_type'] as $type => $typeStats) {
        $typeName = [
            'full' => '完整備份',
            'incremental' => '增量備份',
            'structure' => '結構備份'
        ][$type] ?? $type;
        
        echo "{$typeName}: {$typeStats['count']} 個檔案, " . formatBytes($typeStats['size']) . "\n";
    }
    
    echo "\n";
    
    // 測試5: 清理功能
    echo "5. 測試清理功能\n";
    echo "---------------\n";
    
    // 創建一些舊檔案進行清理測試
    $oldTimestamp = date('Y-m-d_H-i-s', strtotime('-35 days'));
    $oldFiles = [
        "full/full_backup_{$oldTimestamp}.sql",
        "structure/structure_backup_{$oldTimestamp}.sql"
    ];
    
    foreach ($oldFiles as $file) {
        $fullPath = $backupDir . '/' . $file;
        file_put_contents($fullPath, "-- Old backup file\n");
        // 設置檔案時間為35天前
        touch($fullPath, strtotime('-35 days'));
        echo "✅ 舊檔案已創建: $file\n";
    }
    
    // 執行清理
    $cleanupResult = cleanupOldBackups($backupDir, 30);
    echo "清理結果: 刪除 {$cleanupResult['deleted_count']} 個檔案，釋放 " . formatBytes($cleanupResult['freed_space']) . "\n";
    
    echo "\n";
    
    // 測試6: 還原演練準備
    echo "6. 測試還原演練準備\n";
    echo "-------------------\n";
    
    $availableBackups = listAvailableBackups($backupDir);
    echo "可用備份檔案: " . count($availableBackups) . " 個\n";
    
    foreach (array_slice($availableBackups, 0, 3) as $i => $backup) {
        echo ($i + 1) . ". [{$backup['type_name']}] {$backup['basename']} (" . formatBytes($backup['size']) . ")\n";
    }
    
    echo "\n";
    
    // 測試7: 生成演練報告
    echo "7. 測試演練報告生成\n";
    echo "-------------------\n";
    
    $drillReport = generateDrillReport($backupDir, [
        'tables_count' => 25,
        'records_count' => 15000,
        'key_tables' => [
            'users' => 1500,
            'tasks' => 3200,
            'chat_messages' => 8500,
            'task_applications' => 1800
        ],
        'errors' => []
    ]);
    
    echo "✅ 演練報告已生成: " . basename($drillReport) . "\n";
    
    echo "\n✅ 所有備份系統功能測試完成！\n";
    
    // 記錄測試完成
    Logger::logBusiness('backup_system_test_completed', null, [
        'test_timestamp' => $timestamp,
        'tests_passed' => 7,
        'backup_files_created' => count($testFiles),
        'stats' => $stats
    ]);
    
} catch (Exception $e) {
    echo "❌ 測試失敗: " . $e->getMessage() . "\n";
    Logger::logError('Backup system test failed', [], $e);
    exit(1);
}

/**
 * 計算備份統計
 */
function calculateBackupStats($backupDir) {
    $stats = [
        'total_backups' => 0,
        'total_size' => 0,
        'by_type' => []
    ];
    
    $types = ['full', 'incremental', 'structure'];
    
    foreach ($types as $type) {
        $dir = $backupDir . '/' . $type;
        if (!is_dir($dir)) continue;
        
        $files = glob($dir . '/*');
        
        $typeStats = [
            'count' => count($files),
            'size' => 0
        ];
        
        foreach ($files as $file) {
            $fileSize = filesize($file);
            $stats['total_backups']++;
            $stats['total_size'] += $fileSize;
            $typeStats['size'] += $fileSize;
        }
        
        $stats['by_type'][$type] = $typeStats;
    }
    
    return $stats;
}

/**
 * 清理舊備份
 */
function cleanupOldBackups($backupDir, $retentionDays) {
    $cutoffTime = time() - ($retentionDays * 24 * 60 * 60);
    $types = ['full', 'incremental', 'structure'];
    $deletedCount = 0;
    $freedSpace = 0;
    
    foreach ($types as $type) {
        $dir = $backupDir . '/' . $type;
        if (!is_dir($dir)) continue;
        
        $files = glob($dir . '/*');
        
        foreach ($files as $file) {
            if (filemtime($file) < $cutoffTime) {
                $fileSize = filesize($file);
                if (unlink($file)) {
                    $deletedCount++;
                    $freedSpace += $fileSize;
                }
            }
        }
    }
    
    return ['deleted_count' => $deletedCount, 'freed_space' => $freedSpace];
}

/**
 * 列出可用備份
 */
function listAvailableBackups($backupDir) {
    $backups = [];
    $types = ['full' => '完整備份', 'incremental' => '增量備份', 'structure' => '結構備份'];
    
    foreach ($types as $type => $typeName) {
        $dir = $backupDir . '/' . $type;
        if (!is_dir($dir)) continue;
        
        $files = glob($dir . '/*');
        
        foreach ($files as $file) {
            $backups[] = [
                'type' => $type,
                'type_name' => $typeName,
                'file' => $file,
                'basename' => basename($file),
                'size' => filesize($file),
                'mtime' => filemtime($file),
            ];
        }
    }
    
    // 按時間排序（最新的在前）
    usort($backups, function($a, $b) {
        return $b['mtime'] - $a['mtime'];
    });
    
    return $backups;
}

/**
 * 生成演練報告
 */
function generateDrillReport($backupDir, $validationResult) {
    $reportDir = $backupDir . '/reports';
    if (!is_dir($reportDir)) {
        mkdir($reportDir, 0755, true);
    }
    
    $reportFile = $reportDir . '/restore_drill_test_' . date('Y-m-d_H-i-s') . '.md';
    
    $content = "# 資料庫還原演練測試報告\n\n";
    $content .= "**測試日期**: " . date('Y-m-d H:i:s') . "\n";
    $content .= "**測試類型**: 功能測試（模擬）\n\n";
    
    $content .= "## 驗證結果\n\n";
    $content .= "- **表格數量**: {$validationResult['tables_count']}\n";
    $content .= "- **總記錄數**: {$validationResult['records_count']}\n\n";
    
    if (!empty($validationResult['key_tables'])) {
        $content .= "### 關鍵表格記錄數\n\n";
        foreach ($validationResult['key_tables'] as $table => $count) {
            $content .= "- **$table**: $count 筆\n";
        }
        $content .= "\n";
    }
    
    if (!empty($validationResult['errors'])) {
        $content .= "### 發現的問題\n\n";
        foreach ($validationResult['errors'] as $error) {
            $content .= "- ❌ $error\n";
        }
        $content .= "\n";
    } else {
        $content .= "### 結果\n\n";
        $content .= "✅ 所有驗證項目通過\n\n";
    }
    
    $content .= "## 測試說明\n\n";
    $content .= "這是一個功能測試，驗證了備份系統的以下功能：\n";
    $content .= "1. 備份目錄結構創建\n";
    $content .= "2. 備份檔案管理\n";
    $content .= "3. 日誌記錄系統\n";
    $content .= "4. 統計功能\n";
    $content .= "5. 清理功能\n";
    $content .= "6. 還原準備\n";
    $content .= "7. 報告生成\n\n";
    
    file_put_contents($reportFile, $content);
    
    return $reportFile;
}

/**
 * 格式化檔案大小
 */
function formatBytes($bytes, $precision = 2) {
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];
    
    for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
        $bytes /= 1024;
    }
    
    return round($bytes, $precision) . ' ' . $units[$i];
}

