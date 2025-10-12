<?php
/**
 * 資料庫還原管理器
 * 支援完整還原、增量還原和還原演練
 */

require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../utils/Logger.php';

class RestoreManager {
    private $db;
    private $backupDir;
    private $config;
    private $testDbName;
    
    public function __construct() {
        $this->db = Database::getInstance()->getConnection();
        $this->backupDir = __DIR__ . '/backups';
        $this->loadConfig();
        $this->testDbName = $this->config['db_name'] . '_restore_test';
    }
    
    /**
     * 載入配置
     */
    private function loadConfig() {
        $this->config = [
            'db_host' => $_ENV['DB_HOST'] ?? 'localhost',
            'db_port' => $_ENV['DB_PORT'] ?? '8889',
            'db_name' => $_ENV['DB_DATABASE'] ?? '',
            'db_user' => $_ENV['DB_USERNAME'] ?? '',
            'db_pass' => $_ENV['DB_PASSWORD'] ?? '',
        ];
    }
    
    /**
     * 列出可用的備份檔案
     */
    public function listAvailableBackups() {
        echo "📋 可用的備份檔案\n";
        echo "================\n\n";
        
        $backups = [];
        $types = ['full' => '完整備份', 'incremental' => '增量備份', 'structure' => '結構備份'];
        
        foreach ($types as $type => $typeName) {
            $dir = $this->backupDir . '/' . $type;
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
        
        if (empty($backups)) {
            echo "沒有找到備份檔案\n";
            return [];
        }
        
        foreach ($backups as $i => $backup) {
            $size = $this->formatBytes($backup['size']);
            $time = date('Y-m-d H:i:s', $backup['mtime']);
            
            echo ($i + 1) . ". [{$backup['type_name']}] {$backup['basename']}\n";
            echo "   大小: $size, 時間: $time\n";
            echo "   路徑: {$backup['file']}\n\n";
        }
        
        return $backups;
    }
    
    /**
     * 執行還原演練
     */
    public function performRestoreDrill($backupFile = null) {
        echo "🧪 執行還原演練\n";
        echo "==============\n\n";
        
        try {
            // 如果沒有指定備份檔案，使用最新的完整備份
            if (!$backupFile) {
                $backupFile = $this->getLatestFullBackup();
                if (!$backupFile) {
                    throw new Exception("沒有找到可用的完整備份檔案");
                }
            }
            
            if (!file_exists($backupFile)) {
                throw new Exception("備份檔案不存在: $backupFile");
            }
            
            echo "使用備份檔案: " . basename($backupFile) . "\n";
            echo "檔案大小: " . $this->formatBytes(filesize($backupFile)) . "\n\n";
            
            $startTime = microtime(true);
            
            // 步驟1：創建測試資料庫
            echo "步驟1: 創建測試資料庫\n";
            $this->createTestDatabase();
            
            // 步驟2：還原備份到測試資料庫
            echo "步驟2: 還原備份到測試資料庫\n";
            $this->restoreToTestDatabase($backupFile);
            
            // 步驟3：驗證還原結果
            echo "步驟3: 驗證還原結果\n";
            $validationResult = $this->validateRestore();
            
            // 步驟4：清理測試資料庫
            echo "步驟4: 清理測試資料庫\n";
            $this->cleanupTestDatabase();
            
            $duration = round(microtime(true) - $startTime, 2);
            
            echo "\n✅ 還原演練完成！\n";
            echo "總耗時: {$duration} 秒\n";
            
            // 生成演練報告
            $this->generateDrillReport($backupFile, $validationResult, $duration);
            
            // 記錄演練日誌
            Logger::logBusiness('restore_drill_completed', null, [
                'backup_file' => basename($backupFile),
                'duration' => $duration,
                'validation_result' => $validationResult,
                'success' => true
            ]);
            
            return true;
            
        } catch (Exception $e) {
            echo "❌ 還原演練失敗: " . $e->getMessage() . "\n";
            
            // 確保清理測試資料庫
            try {
                $this->cleanupTestDatabase();
            } catch (Exception $cleanupError) {
                echo "⚠️  清理測試資料庫失敗: " . $cleanupError->getMessage() . "\n";
            }
            
            Logger::logError('Restore drill failed', [
                'backup_file' => $backupFile ? basename($backupFile) : 'unknown',
                'error' => $e->getMessage()
            ], $e);
            
            throw $e;
        }
    }
    
    /**
     * 執行實際還原（危險操作）
     */
    public function performActualRestore($backupFile, $confirmationCode) {
        // 安全確認機制
        $expectedCode = strtoupper(substr(md5($backupFile . date('Y-m-d')), 0, 8));
        
        if ($confirmationCode !== $expectedCode) {
            throw new Exception("確認碼錯誤。今日的確認碼是: $expectedCode");
        }
        
        echo "🚨 執行實際資料庫還原\n";
        echo "====================\n";
        echo "⚠️  這是一個危險操作，將會覆蓋現有資料庫！\n\n";
        
        if (!file_exists($backupFile)) {
            throw new Exception("備份檔案不存在: $backupFile");
        }
        
        try {
            $startTime = microtime(true);
            
            // 步驟1：創建當前資料庫的緊急備份
            echo "步驟1: 創建緊急備份\n";
            $emergencyBackup = $this->createEmergencyBackup();
            
            // 步驟2：執行還原
            echo "步驟2: 執行資料庫還原\n";
            $this->restoreToProductionDatabase($backupFile);
            
            // 步驟3：驗證還原結果
            echo "步驟3: 驗證還原結果\n";
            $validationResult = $this->validateProductionRestore();
            
            $duration = round(microtime(true) - $startTime, 2);
            
            echo "\n✅ 資料庫還原完成！\n";
            echo "總耗時: {$duration} 秒\n";
            echo "緊急備份: " . basename($emergencyBackup) . "\n";
            
            // 記錄還原日誌
            Logger::logBusiness('database_restore_completed', null, [
                'backup_file' => basename($backupFile),
                'emergency_backup' => basename($emergencyBackup),
                'duration' => $duration,
                'validation_result' => $validationResult,
                'confirmation_code' => $confirmationCode
            ]);
            
            return true;
            
        } catch (Exception $e) {
            echo "❌ 資料庫還原失敗: " . $e->getMessage() . "\n";
            
            Logger::logError('Database restore failed', [
                'backup_file' => basename($backupFile),
                'error' => $e->getMessage()
            ], $e);
            
            throw $e;
        }
    }
    
    /**
     * 創建測試資料庫
     */
    private function createTestDatabase() {
        // 先刪除如果存在
        $this->db->exec("DROP DATABASE IF EXISTS `{$this->testDbName}`");
        
        // 創建新的測試資料庫
        $this->db->exec("CREATE DATABASE `{$this->testDbName}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
        
        echo "✅ 測試資料庫已創建: {$this->testDbName}\n";
    }
    
    /**
     * 還原到測試資料庫
     */
    private function restoreToTestDatabase($backupFile) {
        $command = $this->buildMysqlCommand($backupFile, $this->testDbName);
        
        echo "執行還原命令...\n";
        $output = [];
        $returnCode = 0;
        exec($command, $output, $returnCode);
        
        if ($returnCode !== 0) {
            throw new Exception("mysql 還原失敗，返回碼: $returnCode\n輸出: " . implode("\n", $output));
        }
        
        echo "✅ 備份已還原到測試資料庫\n";
    }
    
    /**
     * 還原到生產資料庫
     */
    private function restoreToProductionDatabase($backupFile) {
        $command = $this->buildMysqlCommand($backupFile, $this->config['db_name']);
        
        echo "執行還原命令...\n";
        $output = [];
        $returnCode = 0;
        exec($command, $output, $returnCode);
        
        if ($returnCode !== 0) {
            throw new Exception("mysql 還原失敗，返回碼: $returnCode\n輸出: " . implode("\n", $output));
        }
        
        echo "✅ 備份已還原到生產資料庫\n";
    }
    
    /**
     * 驗證還原結果
     */
    private function validateRestore() {
        echo "驗證測試資料庫...\n";
        
        // 創建測試資料庫連接
        $testDsn = "mysql:host={$this->config['db_host']};port={$this->config['db_port']};dbname={$this->testDbName};charset=utf8mb4";
        $testDb = new PDO($testDsn, $this->config['db_user'], $this->config['db_pass']);
        
        $validationResult = [
            'tables_count' => 0,
            'records_count' => 0,
            'key_tables' => [],
            'errors' => []
        ];
        
        try {
            // 檢查表格數量
            $stmt = $testDb->query("SHOW TABLES");
            $tables = $stmt->fetchAll(PDO::FETCH_COLUMN);
            $validationResult['tables_count'] = count($tables);
            
            echo "發現 {$validationResult['tables_count']} 個表格\n";
            
            // 檢查關鍵表格的記錄數
            $keyTables = ['users', 'tasks', 'chat_messages', 'task_applications'];
            
            foreach ($keyTables as $table) {
                if (in_array($table, $tables)) {
                    $stmt = $testDb->query("SELECT COUNT(*) FROM `$table`");
                    $count = $stmt->fetchColumn();
                    $validationResult['key_tables'][$table] = $count;
                    echo "- $table: $count 筆記錄\n";
                } else {
                    $validationResult['errors'][] = "缺少關鍵表格: $table";
                }
            }
            
            // 計算總記錄數
            $totalRecords = 0;
            foreach ($tables as $table) {
                try {
                    $stmt = $testDb->query("SELECT COUNT(*) FROM `$table`");
                    $totalRecords += $stmt->fetchColumn();
                } catch (Exception $e) {
                    $validationResult['errors'][] = "無法查詢表格 $table: " . $e->getMessage();
                }
            }
            
            $validationResult['records_count'] = $totalRecords;
            echo "總記錄數: $totalRecords\n";
            
            if (empty($validationResult['errors'])) {
                echo "✅ 驗證通過\n";
            } else {
                echo "⚠️  發現 " . count($validationResult['errors']) . " 個問題\n";
                foreach ($validationResult['errors'] as $error) {
                    echo "  - $error\n";
                }
            }
            
        } catch (Exception $e) {
            $validationResult['errors'][] = "驗證過程發生錯誤: " . $e->getMessage();
            echo "❌ 驗證失敗: " . $e->getMessage() . "\n";
        }
        
        return $validationResult;
    }
    
    /**
     * 驗證生產資料庫還原
     */
    private function validateProductionRestore() {
        echo "驗證生產資料庫...\n";
        
        $validationResult = [
            'tables_count' => 0,
            'records_count' => 0,
            'key_tables' => [],
            'errors' => []
        ];
        
        try {
            // 檢查表格數量
            $stmt = $this->db->query("SHOW TABLES");
            $tables = $stmt->fetchAll(PDO::FETCH_COLUMN);
            $validationResult['tables_count'] = count($tables);
            
            echo "發現 {$validationResult['tables_count']} 個表格\n";
            
            // 檢查關鍵表格
            $keyTables = ['users', 'tasks', 'chat_messages', 'task_applications'];
            
            foreach ($keyTables as $table) {
                if (in_array($table, $tables)) {
                    $stmt = $this->db->query("SELECT COUNT(*) FROM `$table`");
                    $count = $stmt->fetchColumn();
                    $validationResult['key_tables'][$table] = $count;
                    echo "- $table: $count 筆記錄\n";
                } else {
                    $validationResult['errors'][] = "缺少關鍵表格: $table";
                }
            }
            
            if (empty($validationResult['errors'])) {
                echo "✅ 生產資料庫驗證通過\n";
            } else {
                echo "⚠️  發現問題，請檢查\n";
            }
            
        } catch (Exception $e) {
            $validationResult['errors'][] = "驗證過程發生錯誤: " . $e->getMessage();
            echo "❌ 生產資料庫驗證失敗: " . $e->getMessage() . "\n";
        }
        
        return $validationResult;
    }
    
    /**
     * 清理測試資料庫
     */
    private function cleanupTestDatabase() {
        $this->db->exec("DROP DATABASE IF EXISTS `{$this->testDbName}`");
        echo "✅ 測試資料庫已清理\n";
    }
    
    /**
     * 創建緊急備份
     */
    private function createEmergencyBackup() {
        $timestamp = date('Y-m-d_H-i-s');
        $backupFile = $this->backupDir . "/emergency/emergency_backup_{$timestamp}.sql";
        
        // 確保緊急備份目錄存在
        $emergencyDir = dirname($backupFile);
        if (!is_dir($emergencyDir)) {
            mkdir($emergencyDir, 0755, true);
        }
        
        $command = "mysqldump";
        $command .= " -h{$this->config['db_host']}";
        $command .= " -P{$this->config['db_port']}";
        $command .= " -u{$this->config['db_user']}";
        
        if (!empty($this->config['db_pass'])) {
            $command .= " -p'" . addslashes($this->config['db_pass']) . "'";
        }
        
        $command .= " --single-transaction";
        $command .= " --routines";
        $command .= " --triggers";
        $command .= " {$this->config['db_name']}";
        $command .= " > " . escapeshellarg($backupFile);
        
        $output = [];
        $returnCode = 0;
        exec($command, $output, $returnCode);
        
        if ($returnCode !== 0 || !file_exists($backupFile)) {
            throw new Exception("緊急備份創建失敗");
        }
        
        echo "✅ 緊急備份已創建: " . basename($backupFile) . "\n";
        return $backupFile;
    }
    
    /**
     * 建構 mysql 命令
     */
    private function buildMysqlCommand($backupFile, $targetDatabase) {
        $command = "mysql";
        $command .= " -h{$this->config['db_host']}";
        $command .= " -P{$this->config['db_port']}";
        $command .= " -u{$this->config['db_user']}";
        
        if (!empty($this->config['db_pass'])) {
            $command .= " -p'" . addslashes($this->config['db_pass']) . "'";
        }
        
        $command .= " $targetDatabase";
        
        // 處理壓縮檔案
        if (pathinfo($backupFile, PATHINFO_EXTENSION) === 'gz') {
            $command = "gunzip -c " . escapeshellarg($backupFile) . " | " . $command;
        } else {
            $command .= " < " . escapeshellarg($backupFile);
        }
        
        return $command;
    }
    
    /**
     * 獲取最新的完整備份
     */
    private function getLatestFullBackup() {
        $fullBackupDir = $this->backupDir . '/full';
        
        if (!is_dir($fullBackupDir)) {
            return null;
        }
        
        $files = glob($fullBackupDir . '/*');
        
        if (empty($files)) {
            return null;
        }
        
        // 按修改時間排序，最新的在前
        usort($files, function($a, $b) {
            return filemtime($b) - filemtime($a);
        });
        
        return $files[0];
    }
    
    /**
     * 生成演練報告
     */
    private function generateDrillReport($backupFile, $validationResult, $duration) {
        $reportDir = $this->backupDir . '/reports';
        if (!is_dir($reportDir)) {
            mkdir($reportDir, 0755, true);
        }
        
        $reportFile = $reportDir . '/restore_drill_' . date('Y-m-d_H-i-s') . '.md';
        
        $content = "# 資料庫還原演練報告\n\n";
        $content .= "**演練日期**: " . date('Y-m-d H:i:s') . "\n";
        $content .= "**備份檔案**: " . basename($backupFile) . "\n";
        $content .= "**總耗時**: {$duration} 秒\n\n";
        
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
        
        $content .= "## 建議\n\n";
        $content .= "1. 定期執行還原演練以確保備份可用性\n";
        $content .= "2. 監控備份檔案大小和完整性\n";
        $content .= "3. 測試不同時間點的備份檔案\n";
        $content .= "4. 確保還原程序文件是最新的\n";
        
        file_put_contents($reportFile, $content);
        
        echo "📄 演練報告已生成: " . basename($reportFile) . "\n";
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
}

// 如果直接執行此腳本
if (basename(__FILE__) === basename($_SERVER['SCRIPT_NAME'])) {
    try {
        $manager = new RestoreManager();
        
        if ($argc > 1) {
            switch ($argv[1]) {
                case 'list':
                    $manager->listAvailableBackups();
                    break;
                    
                case 'drill':
                    $backupFile = $argv[2] ?? null;
                    $manager->performRestoreDrill($backupFile);
                    break;
                    
                case 'restore':
                    if ($argc < 4) {
                        echo "用法: php restore_manager.php restore <backup_file> <confirmation_code>\n";
                        exit(1);
                    }
                    $backupFile = $argv[2];
                    $confirmationCode = $argv[3];
                    $manager->performActualRestore($backupFile, $confirmationCode);
                    break;
                    
                default:
                    echo "用法: php restore_manager.php [list|drill|restore] [backup_file] [confirmation_code]\n";
                    echo "\n";
                    echo "命令說明:\n";
                    echo "  list                     - 列出所有可用的備份檔案\n";
                    echo "  drill [backup_file]      - 執行還原演練（使用測試資料庫）\n";
                    echo "  restore <file> <code>    - 執行實際還原（危險操作）\n";
            }
        } else {
            echo "用法: php restore_manager.php [list|drill|restore] [backup_file] [confirmation_code]\n";
        }
        
    } catch (Exception $e) {
        echo "❌ 操作失敗: " . $e->getMessage() . "\n";
        exit(1);
    }
}
