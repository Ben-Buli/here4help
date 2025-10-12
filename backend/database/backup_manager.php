<?php
/**
 * 資料庫備份管理器
 * 支援完整備份、增量備份和自動化排程
 */

require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../utils/Logger.php';

class BackupManager {
    private $db;
    private $backupDir;
    private $config;
    
    public function __construct() {
        $this->db = Database::getInstance()->getConnection();
        $this->backupDir = __DIR__ . '/backups';
        $this->ensureBackupDirectory();
        $this->loadConfig();
    }
    
    /**
     * 載入備份配置
     */
    private function loadConfig() {
        // 使用 EnvLoader 獲取資料庫配置
        $envLoader = EnvLoader::getInstance();
        $dbConfig = $envLoader->getDatabaseConfig();
        
        $this->config = [
            'db_host' => $dbConfig['host'] ?? '127.0.0.1',
            'db_port' => $dbConfig['port'] ?? '8889',
            'db_name' => $dbConfig['dbname'] ?? '',
            'db_user' => $dbConfig['username'] ?? '',
            'db_pass' => $dbConfig['password'] ?? '',
            'retention_days' => $_ENV['BACKUP_RETENTION_DAYS'] ?? 30,
            'compression' => $_ENV['BACKUP_COMPRESSION'] ?? true,
            'encryption' => $_ENV['BACKUP_ENCRYPTION'] ?? false,
            'remote_storage' => $_ENV['BACKUP_REMOTE_STORAGE'] ?? false,
        ];
    }
    
    /**
     * 確保備份目錄存在
     */
    private function ensureBackupDirectory() {
        if (!is_dir($this->backupDir)) {
            mkdir($this->backupDir, 0755, true);
        }
        
        // 創建子目錄
        $subdirs = ['full', 'incremental', 'structure', 'logs'];
        foreach ($subdirs as $subdir) {
            $path = $this->backupDir . '/' . $subdir;
            if (!is_dir($path)) {
                mkdir($path, 0755, true);
            }
        }
    }
    
    /**
     * 執行完整備份
     */
    public function createFullBackup($description = '') {
        $startTime = microtime(true);
        $timestamp = date('Y-m-d_H-i-s');
        $backupFile = $this->backupDir . "/full/full_backup_{$timestamp}.sql";
        
        echo "🔄 開始完整備份...\n";
        echo "備份檔案: $backupFile\n";
        
        try {
            // 使用 mysqldump 進行備份
            $command = $this->buildMysqldumpCommand($backupFile, 'full');
            
            echo "執行命令: $command\n";
            $output = [];
            $returnCode = 0;
            exec($command . " 2>&1", $output, $returnCode);
            
            if ($returnCode !== 0) {
                $errorOutput = implode("\n", $output);
                echo "錯誤輸出: $errorOutput\n";
                throw new Exception("mysqldump 失敗，返回碼: $returnCode\n輸出: $errorOutput");
            }
            
            // 檢查備份檔案是否存在且有內容
            if (!file_exists($backupFile) || filesize($backupFile) === 0) {
                throw new Exception("備份檔案創建失敗或為空");
            }
            
            // 壓縮備份檔案（如果啟用）
            if ($this->config['compression']) {
                $compressedFile = $this->compressBackup($backupFile);
                unlink($backupFile); // 刪除原始檔案
                $backupFile = $compressedFile;
            }
            
            $duration = round(microtime(true) - $startTime, 2);
            $fileSize = $this->formatBytes(filesize($backupFile));
            
            // 記錄備份資訊
            $backupInfo = [
                'type' => 'full',
                'timestamp' => $timestamp,
                'file' => basename($backupFile),
                'size' => filesize($backupFile),
                'duration' => $duration,
                'description' => $description,
                'tables_count' => $this->getTablesCount(),
                'records_count' => $this->getRecordsCount(),
            ];
            
            $this->logBackup($backupInfo);
            
            echo "✅ 完整備份完成！\n";
            echo "檔案大小: $fileSize\n";
            echo "耗時: {$duration} 秒\n";
            
            Logger::logBusiness('database_backup_completed', null, $backupInfo);
            
            return $backupFile;
            
        } catch (Exception $e) {
            echo "❌ 備份失敗: " . $e->getMessage() . "\n";
            Logger::logError('Database backup failed', ['error' => $e->getMessage()], $e);
            throw $e;
        }
    }
    
    /**
     * 執行結構備份
     */
    public function createStructureBackup($description = '') {
        $startTime = microtime(true);
        $timestamp = date('Y-m-d_H-i-s');
        $backupFile = $this->backupDir . "/structure/structure_backup_{$timestamp}.sql";
        
        echo "🔄 開始結構備份...\n";
        echo "備份檔案: $backupFile\n";
        echo "資料庫配置: {$this->config['db_name']}@{$this->config['db_host']}:{$this->config['db_port']}\n";
        
        try {
            // 使用 mysqldump 進行結構備份（不包含數據）
            $command = $this->buildMysqldumpCommand($backupFile, 'structure');
            
            echo "執行命令: $command\n";
            $output = [];
            $returnCode = 0;
            exec($command . " 2>&1", $output, $returnCode);
            
            if ($returnCode !== 0) {
                $errorOutput = implode("\n", $output);
                echo "錯誤輸出: $errorOutput\n";
                throw new Exception("mysqldump 失敗，返回碼: $returnCode\n輸出: $errorOutput");
            }
            
            if (!file_exists($backupFile) || filesize($backupFile) === 0) {
                throw new Exception("結構備份檔案創建失敗或為空");
            }
            
            $duration = round(microtime(true) - $startTime, 2);
            $fileSize = $this->formatBytes(filesize($backupFile));
            
            // 記錄備份資訊
            $backupInfo = [
                'type' => 'structure',
                'timestamp' => $timestamp,
                'file' => basename($backupFile),
                'size' => filesize($backupFile),
                'duration' => $duration,
                'description' => $description,
                'tables_count' => $this->getTablesCount(),
            ];
            
            $this->logBackup($backupInfo);
            
            echo "✅ 結構備份完成！\n";
            echo "檔案大小: $fileSize\n";
            echo "耗時: {$duration} 秒\n";
            
            return $backupFile;
            
        } catch (Exception $e) {
            echo "❌ 結構備份失敗: " . $e->getMessage() . "\n";
            Logger::logError('Database structure backup failed', ['error' => $e->getMessage()], $e);
            throw $e;
        }
    }
    
    /**
     * 執行增量備份
     */
    public function createIncrementalBackup($description = '') {
        $startTime = microtime(true);
        $timestamp = date('Y-m-d_H-i-s');
        $backupFile = $this->backupDir . "/incremental/incremental_backup_{$timestamp}.sql";
        
        echo "🔄 開始增量備份...\n";
        echo "備份檔案: $backupFile\n";
        
        try {
            // 獲取上次備份時間
            $lastBackupTime = $this->getLastBackupTime();
            
            if (!$lastBackupTime) {
                echo "⚠️  沒有找到上次備份記錄，執行完整備份\n";
                return $this->createFullBackup("自動轉換為完整備份: $description");
            }
            
            // 查找在上次備份後修改的表格
            $modifiedTables = $this->getModifiedTables($lastBackupTime);
            
            if (empty($modifiedTables)) {
                echo "ℹ️  沒有表格被修改，跳過增量備份\n";
                return null;
            }
            
            echo "發現 " . count($modifiedTables) . " 個修改的表格: " . implode(', ', $modifiedTables) . "\n";
            
            // 備份修改的表格
            $command = $this->buildMysqldumpCommand($backupFile, 'incremental', $modifiedTables);
            
            $output = [];
            $returnCode = 0;
            exec($command, $output, $returnCode);
            
            if ($returnCode !== 0) {
                throw new Exception("mysqldump 失敗，返回碼: $returnCode");
            }
            
            if (!file_exists($backupFile) || filesize($backupFile) === 0) {
                throw new Exception("增量備份檔案創建失敗或為空");
            }
            
            // 壓縮備份檔案（如果啟用）
            if ($this->config['compression']) {
                $compressedFile = $this->compressBackup($backupFile);
                unlink($backupFile);
                $backupFile = $compressedFile;
            }
            
            $duration = round(microtime(true) - $startTime, 2);
            $fileSize = $this->formatBytes(filesize($backupFile));
            
            // 記錄備份資訊
            $backupInfo = [
                'type' => 'incremental',
                'timestamp' => $timestamp,
                'file' => basename($backupFile),
                'size' => filesize($backupFile),
                'duration' => $duration,
                'description' => $description,
                'modified_tables' => $modifiedTables,
                'base_backup_time' => $lastBackupTime,
            ];
            
            $this->logBackup($backupInfo);
            
            echo "✅ 增量備份完成！\n";
            echo "檔案大小: $fileSize\n";
            echo "耗時: {$duration} 秒\n";
            
            return $backupFile;
            
        } catch (Exception $e) {
            echo "❌ 增量備份失敗: " . $e->getMessage() . "\n";
            Logger::logError('Database incremental backup failed', ['error' => $e->getMessage()], $e);
            throw $e;
        }
    }
    
    /**
     * 建構 mysqldump 命令
     */
    private function buildMysqldumpCommand($outputFile, $type, $tables = []) {
        $command = "mysqldump";
        
        // 連接參數
        $command .= " -h{$this->config['db_host']}";
        $command .= " -P{$this->config['db_port']}";
        $command .= " -u{$this->config['db_user']}";
        
        if (!empty($this->config['db_pass'])) {
            $command .= " --password=" . escapeshellarg($this->config['db_pass']);
        }
        
        // 備份選項
        $command .= " --single-transaction";
        $command .= " --routines";
        $command .= " --triggers";
        $command .= " --events";
        $command .= " --add-drop-table";
        $command .= " --create-options";
        $command .= " --extended-insert";
        $command .= " --set-charset";
        
        // 根據備份類型設定選項
        switch ($type) {
            case 'structure':
                $command .= " --no-data";
                break;
            case 'incremental':
                $command .= " --where=\"1=1\""; // 可以在這裡添加時間條件
                break;
        }
        
        // 資料庫名稱
        $command .= " {$this->config['db_name']}";
        
        // 指定表格（用於增量備份）
        if (!empty($tables)) {
            $command .= " " . implode(" ", $tables);
        }
        
        // 輸出檔案
        $command .= " > " . escapeshellarg($outputFile);
        
        return $command;
    }
    
    /**
     * 壓縮備份檔案
     */
    private function compressBackup($backupFile) {
        $compressedFile = $backupFile . '.gz';
        
        echo "🗜️  壓縮備份檔案...\n";
        
        $command = "gzip " . escapeshellarg($backupFile);
        exec($command, $output, $returnCode);
        
        if ($returnCode !== 0 || !file_exists($compressedFile)) {
            echo "⚠️  壓縮失敗，保留原始檔案\n";
            return $backupFile;
        }
        
        echo "✅ 壓縮完成\n";
        return $compressedFile;
    }
    
    /**
     * 獲取上次備份時間
     */
    private function getLastBackupTime() {
        $logFile = $this->backupDir . '/logs/backup.log';
        
        if (!file_exists($logFile)) {
            return null;
        }
        
        $lines = file($logFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        $lines = array_reverse($lines);
        
        foreach ($lines as $line) {
            $data = json_decode($line, true);
            if ($data && isset($data['timestamp'])) {
                return $data['timestamp'];
            }
        }
        
        return null;
    }
    
    /**
     * 獲取修改的表格（簡化版本）
     */
    private function getModifiedTables($lastBackupTime) {
        // 這是一個簡化的實作
        // 在實際環境中，可以使用 binlog 或表格的 UPDATE_TIME 來判斷
        
        $sql = "
            SELECT TABLE_NAME, UPDATE_TIME
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_SCHEMA = DATABASE()
            AND TABLE_TYPE = 'BASE TABLE'
            AND UPDATE_TIME > ?
        ";
        
        try {
            $stmt = $this->db->prepare($sql);
            $stmt->execute([date('Y-m-d H:i:s', strtotime($lastBackupTime))]);
            $results = $stmt->fetchAll(PDO::FETCH_COLUMN);
            
            return $results ?: [];
        } catch (Exception $e) {
            // 如果無法判斷修改時間，返回所有主要表格
            return ['users', 'tasks', 'chat_messages', 'task_applications'];
        }
    }
    
    /**
     * 獲取表格數量
     */
    private function getTablesCount() {
        $stmt = $this->db->query("
            SELECT COUNT(*) 
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_SCHEMA = DATABASE()
            AND TABLE_TYPE = 'BASE TABLE'
        ");
        return $stmt->fetchColumn();
    }
    
    /**
     * 獲取記錄總數
     */
    private function getRecordsCount() {
        $stmt = $this->db->query("
            SELECT SUM(TABLE_ROWS) 
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_SCHEMA = DATABASE()
            AND TABLE_TYPE = 'BASE TABLE'
        ");
        return $stmt->fetchColumn() ?: 0;
    }
    
    /**
     * 記錄備份資訊
     */
    private function logBackup($backupInfo) {
        $logFile = $this->backupDir . '/logs/backup.log';
        $logEntry = json_encode($backupInfo) . "\n";
        file_put_contents($logFile, $logEntry, FILE_APPEND | LOCK_EX);
    }
    
    /**
     * 格式化檔案大小
     */
    private function formatBytes($bytes, $precision = 2) {
        $units = ['B', 'KB', 'MB', 'GB', 'TB'];
        
        for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
            $bytes /= 1024;
        }
        
        return round($bytes, $precision) . ' ' . $units[$i];
    }
    
    /**
     * 清理舊備份
     */
    public function cleanupOldBackups() {
        $retentionDays = (int)$this->config['retention_days'];
        $cutoffTime = time() - ($retentionDays * 24 * 60 * 60);
        
        echo "🧹 清理 {$retentionDays} 天前的舊備份...\n";
        
        $types = ['full', 'incremental', 'structure'];
        $deletedCount = 0;
        $freedSpace = 0;
        
        foreach ($types as $type) {
            $dir = $this->backupDir . '/' . $type;
            $files = glob($dir . '/*');
            
            foreach ($files as $file) {
                if (filemtime($file) < $cutoffTime) {
                    $fileSize = filesize($file);
                    if (unlink($file)) {
                        $deletedCount++;
                        $freedSpace += $fileSize;
                        echo "刪除: " . basename($file) . "\n";
                    }
                }
            }
        }
        
        if ($deletedCount > 0) {
            echo "✅ 清理完成：刪除 {$deletedCount} 個檔案，釋放 " . $this->formatBytes($freedSpace) . "\n";
        } else {
            echo "ℹ️  沒有需要清理的舊備份\n";
        }
        
        return ['deleted_count' => $deletedCount, 'freed_space' => $freedSpace];
    }
    
    /**
     * 列出所有備份
     */
    public function listBackups() {
        echo "📋 備份檔案列表\n";
        echo "===============\n\n";
        
        $types = ['full' => '完整備份', 'incremental' => '增量備份', 'structure' => '結構備份'];
        
        foreach ($types as $type => $typeName) {
            echo "### {$typeName}\n";
            
            $dir = $this->backupDir . '/' . $type;
            $files = glob($dir . '/*');
            
            if (empty($files)) {
                echo "沒有找到備份檔案\n\n";
                continue;
            }
            
            // 按修改時間排序（最新的在前）
            usort($files, function($a, $b) {
                return filemtime($b) - filemtime($a);
            });
            
            foreach ($files as $file) {
                $fileName = basename($file);
                $fileSize = $this->formatBytes(filesize($file));
                $fileTime = date('Y-m-d H:i:s', filemtime($file));
                
                echo "- {$fileName} ({$fileSize}) - {$fileTime}\n";
            }
            
            echo "\n";
        }
    }
    
    /**
     * 獲取備份統計
     */
    public function getBackupStats() {
        $stats = [
            'total_backups' => 0,
            'total_size' => 0,
            'by_type' => [],
            'latest_backup' => null,
            'oldest_backup' => null,
        ];
        
        $types = ['full', 'incremental', 'structure'];
        
        foreach ($types as $type) {
            $dir = $this->backupDir . '/' . $type;
            $files = glob($dir . '/*');
            
            $typeStats = [
                'count' => count($files),
                'size' => 0,
                'latest' => null,
                'oldest' => null,
            ];
            
            foreach ($files as $file) {
                $fileSize = filesize($file);
                $fileTime = filemtime($file);
                
                $stats['total_backups']++;
                $stats['total_size'] += $fileSize;
                $typeStats['size'] += $fileSize;
                
                if (!$typeStats['latest'] || $fileTime > $typeStats['latest']) {
                    $typeStats['latest'] = $fileTime;
                }
                
                if (!$typeStats['oldest'] || $fileTime < $typeStats['oldest']) {
                    $typeStats['oldest'] = $fileTime;
                }
                
                if (!$stats['latest_backup'] || $fileTime > $stats['latest_backup']) {
                    $stats['latest_backup'] = $fileTime;
                }
                
                if (!$stats['oldest_backup'] || $fileTime < $stats['oldest_backup']) {
                    $stats['oldest_backup'] = $fileTime;
                }
            }
            
            $stats['by_type'][$type] = $typeStats;
        }
        
        return $stats;
    }
}

// 如果直接執行此腳本
if (basename(__FILE__) === basename($_SERVER['SCRIPT_NAME'])) {
    try {
        $manager = new BackupManager();
        
        // 簡單的命令行介面
        if ($argc > 1) {
            switch ($argv[1]) {
                case 'full':
                    $description = $argv[2] ?? '手動完整備份';
                    $manager->createFullBackup($description);
                    break;
                    
                case 'structure':
                    $description = $argv[2] ?? '手動結構備份';
                    $manager->createStructureBackup($description);
                    break;
                    
                case 'incremental':
                    $description = $argv[2] ?? '手動增量備份';
                    $manager->createIncrementalBackup($description);
                    break;
                    
                case 'cleanup':
                    $manager->cleanupOldBackups();
                    break;
                    
                case 'list':
                    $manager->listBackups();
                    break;
                    
                case 'stats':
                    $stats = $manager->getBackupStats();
                    echo "備份統計:\n";
                    echo "總備份數: {$stats['total_backups']}\n";
                    // 修正：直接在這裡實作 bytes 格式化，避免呼叫不存在的方法
                    function formatBytes($bytes, $precision = 2) {
                        $units = array('B', 'KB', 'MB', 'GB', 'TB');
                        $bytes = max($bytes, 0);
                        $pow = $bytes > 0 ? floor(log($bytes) / log(1024)) : 0;
                        $pow = min($pow, count($units) - 1);
                        $bytes /= pow(1024, $pow);
                        return round($bytes, $precision) . ' ' . $units[$pow];
                    }
                    echo "總大小: " . formatBytes($stats['total_size']) . "\n";
                    
                    if ($stats['latest_backup']) {
                        echo "最新備份: " . date('Y-m-d H:i:s', $stats['latest_backup']) . "\n";
                    }
                    break;
                    
                default:
                    echo "用法: php backup_manager.php [full|structure|incremental|cleanup|list|stats] [description]\n";
            }
        } else {
            echo "用法: php backup_manager.php [full|structure|incremental|cleanup|list|stats] [description]\n";
        }
        
    } catch (Exception $e) {
        echo "❌ 操作失敗: " . $e->getMessage() . "\n";
        exit(1);
    }
}
