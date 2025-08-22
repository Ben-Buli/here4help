<?php
/**
 * 資料庫備份 Cron 腳本
 * 支援每日完整備份和每6小時增量備份
 */

require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../database/backup_manager.php';
require_once __DIR__ . '/../utils/Logger.php';

// 禁用自動日誌記錄
define('LOGGING_MIDDLEWARE_DISABLED', true);

echo "🗄️ Here4Help 資料庫備份系統\n";
echo "===========================\n\n";

try {
    $manager = new BackupManager();
    
    // 獲取當前時間
    $currentHour = (int)date('H');
    $currentMinute = (int)date('i');
    
    // 判斷備份類型
    $backupType = determineBackupType($currentHour, $currentMinute);
    
    echo "當前時間: " . date('Y-m-d H:i:s') . "\n";
    echo "備份類型: $backupType\n\n";
    
    switch ($backupType) {
        case 'full':
            performFullBackup($manager);
            break;
            
        case 'incremental':
            performIncrementalBackup($manager);
            break;
            
        case 'structure':
            performStructureBackup($manager);
            break;
            
        default:
            echo "ℹ️  當前時間不需要執行備份\n";
            break;
    }
    
    // 每次執行都檢查是否需要清理舊備份
    if ($currentHour === 2 && $currentMinute < 30) { // 凌晨2點執行清理
        echo "\n🧹 執行備份清理...\n";
        $cleanupResult = $manager->cleanupOldBackups();
        
        if ($cleanupResult['deleted_count'] > 0) {
            Logger::logBusiness('backup_cleanup_completed', null, $cleanupResult);
        }
    }
    
    // 顯示備份統計
    echo "\n📊 備份統計:\n";
    displayBackupStats($manager);
    
    echo "\n✅ 備份任務完成\n";
    
} catch (Exception $e) {
    echo "❌ 備份失敗: " . $e->getMessage() . "\n";
    Logger::logError('Database backup cron failed', [], $e);
    exit(1);
}

/**
 * 判斷備份類型
 */
function determineBackupType($hour, $minute) {
    // 每日凌晨1點執行完整備份
    if ($hour === 1 && $minute >= 0 && $minute < 30) {
        return 'full';
    }
    
    // 每6小時執行增量備份（6, 12, 18點）
    if (in_array($hour, [6, 12, 18]) && $minute >= 0 && $minute < 30) {
        return 'incremental';
    }
    
    // 每週日凌晨3點執行結構備份
    if (date('w') == 0 && $hour === 3 && $minute >= 0 && $minute < 30) {
        return 'structure';
    }
    
    return 'none';
}

/**
 * 執行完整備份
 */
function performFullBackup($manager) {
    echo "🔄 執行每日完整備份\n";
    echo "==================\n";
    
    $description = "每日自動完整備份 - " . date('Y-m-d');
    
    $startTime = microtime(true);
    $backupFile = $manager->createFullBackup($description);
    $duration = round(microtime(true) - $startTime, 2);
    
    // 驗證備份檔案
    if ($backupFile && file_exists($backupFile)) {
        $fileSize = formatBytes(filesize($backupFile));
        echo "✅ 完整備份成功完成\n";
        echo "備份檔案: " . basename($backupFile) . "\n";
        echo "檔案大小: $fileSize\n";
        echo "總耗時: {$duration} 秒\n";
        
        // 記錄成功日誌
        Logger::logBusiness('daily_full_backup_completed', null, [
            'backup_file' => basename($backupFile),
            'file_size' => filesize($backupFile),
            'duration' => $duration,
            'description' => $description
        ]);
        
        // 可選：上傳到遠端存儲
        // uploadToRemoteStorage($backupFile);
        
    } else {
        throw new Exception("完整備份檔案創建失敗");
    }
}

/**
 * 執行增量備份
 */
function performIncrementalBackup($manager) {
    echo "🔄 執行增量備份\n";
    echo "==============\n";
    
    $description = "自動增量備份 - " . date('Y-m-d H:i');
    
    $startTime = microtime(true);
    $backupFile = $manager->createIncrementalBackup($description);
    $duration = round(microtime(true) - $startTime, 2);
    
    if ($backupFile && file_exists($backupFile)) {
        $fileSize = formatBytes(filesize($backupFile));
        echo "✅ 增量備份成功完成\n";
        echo "備份檔案: " . basename($backupFile) . "\n";
        echo "檔案大小: $fileSize\n";
        echo "總耗時: {$duration} 秒\n";
        
        // 記錄成功日誌
        Logger::logBusiness('incremental_backup_completed', null, [
            'backup_file' => basename($backupFile),
            'file_size' => filesize($backupFile),
            'duration' => $duration,
            'description' => $description
        ]);
        
    } elseif ($backupFile === null) {
        echo "ℹ️  沒有數據變更，跳過增量備份\n";
    } else {
        throw new Exception("增量備份檔案創建失敗");
    }
}

/**
 * 執行結構備份
 */
function performStructureBackup($manager) {
    echo "🔄 執行結構備份\n";
    echo "==============\n";
    
    $description = "每週自動結構備份 - " . date('Y-m-d');
    
    $startTime = microtime(true);
    $backupFile = $manager->createStructureBackup($description);
    $duration = round(microtime(true) - $startTime, 2);
    
    if ($backupFile && file_exists($backupFile)) {
        $fileSize = formatBytes(filesize($backupFile));
        echo "✅ 結構備份成功完成\n";
        echo "備份檔案: " . basename($backupFile) . "\n";
        echo "檔案大小: $fileSize\n";
        echo "總耗時: {$duration} 秒\n";
        
        // 記錄成功日誌
        Logger::logBusiness('structure_backup_completed', null, [
            'backup_file' => basename($backupFile),
            'file_size' => filesize($backupFile),
            'duration' => $duration,
            'description' => $description
        ]);
        
    } else {
        throw new Exception("結構備份檔案創建失敗");
    }
}

/**
 * 顯示備份統計
 */
function displayBackupStats($manager) {
    $stats = $manager->getBackupStats();
    
    echo "總備份數: {$stats['total_backups']}\n";
    echo "總大小: " . formatBytes($stats['total_size']) . "\n";
    
    if ($stats['latest_backup']) {
        echo "最新備份: " . date('Y-m-d H:i:s', $stats['latest_backup']) . "\n";
    }
    
    foreach ($stats['by_type'] as $type => $typeStats) {
        $typeName = [
            'full' => '完整備份',
            'incremental' => '增量備份',
            'structure' => '結構備份'
        ][$type] ?? $type;
        
        echo "{$typeName}: {$typeStats['count']} 個檔案, " . formatBytes($typeStats['size']) . "\n";
    }
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

/**
 * 上傳到遠端存儲（佔位符）
 */
function uploadToRemoteStorage($backupFile) {
    // TODO: 實現遠端存儲上傳
    // 例如：AWS S3, Google Cloud Storage, FTP 等
    
    echo "ℹ️  遠端存儲上傳功能尚未實現\n";
}

