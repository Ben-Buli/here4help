<?php
/**
 * 資料庫管理主控腳本
 * 整合驗證、修復和報告生成功能
 */

require_once '../config/database.php';
require_once 'validate_structure.php';
require_once 'fix_structure.php';
require_once 'generate_report.php';

class DatabaseManager {
    private $db;
    
    public function __construct() {
        $this->db = Database::getInstance();
    }
    
    public function showMenu() {
        echo "\n=== 資料庫管理工具 ===\n";
        echo "1. 驗證資料庫結構\n";
        echo "2. 修復資料庫結構\n";
        echo "3. 生成結構報告\n";
        echo "4. 完整檢查和修復\n";
        echo "5. 查看資料庫狀態\n";
        echo "6. 備份資料庫結構\n";
        echo "0. 退出\n";
        echo "請選擇操作 (0-6): ";
        
        $choice = trim(fgets(STDIN));
        
        switch ($choice) {
            case '1':
                $this->validateDatabase();
                break;
            case '2':
                $this->fixDatabase();
                break;
            case '3':
                $this->generateReport();
                break;
            case '4':
                $this->fullCheckAndFix();
                break;
            case '5':
                $this->showDatabaseStatus();
                break;
            case '6':
                $this->backupStructure();
                break;
            case '0':
                echo "再見！\n";
                exit(0);
            default:
                echo "無效選擇，請重試。\n";
                $this->showMenu();
        }
    }
    
    private function validateDatabase() {
        echo "\n=== 開始驗證資料庫結構 ===\n";
        try {
            $validator = new DatabaseStructureValidator();
            $validator->validateAll();
        } catch (Exception $e) {
            echo "驗證失敗: " . $e->getMessage() . "\n";
        }
        
        echo "\n按 Enter 鍵繼續...";
        fgets(STDIN);
        $this->showMenu();
    }
    
    private function fixDatabase() {
        echo "\n=== 開始修復資料庫結構 ===\n";
        echo "警告：此操作將修改資料庫結構，請確認您已備份資料庫。\n";
        echo "是否繼續？(y/N): ";
        
        $confirm = trim(fgets(STDIN));
        if (strtolower($confirm) !== 'y') {
            echo "操作已取消。\n";
            $this->showMenu();
            return;
        }
        
        try {
            $fixer = new DatabaseStructureFixer();
            $fixer->fixAll();
        } catch (Exception $e) {
            echo "修復失敗: " . $e->getMessage() . "\n";
        }
        
        echo "\n按 Enter 鍵繼續...";
        fgets(STDIN);
        $this->showMenu();
    }
    
    private function generateReport() {
        echo "\n=== 開始生成資料庫結構報告 ===\n";
        try {
            $generator = new DatabaseReportGenerator();
            $generator->generateReport();
        } catch (Exception $e) {
            echo "報告生成失敗: " . $e->getMessage() . "\n";
        }
        
        echo "\n按 Enter 鍵繼續...";
        fgets(STDIN);
        $this->showMenu();
    }
    
    private function fullCheckAndFix() {
        echo "\n=== 完整檢查和修復 ===\n";
        echo "此操作將執行以下步驟：\n";
        echo "1. 驗證資料庫結構\n";
        echo "2. 修復發現的問題\n";
        echo "3. 生成修復後報告\n";
        echo "是否繼續？(y/N): ";
        
        $confirm = trim(fgets(STDIN));
        if (strtolower($confirm) !== 'y') {
            echo "操作已取消。\n";
            $this->showMenu();
            return;
        }
        
        try {
            // 步驟 1: 驗證
            echo "\n--- 步驟 1: 驗證資料庫結構 ---\n";
            $validator = new DatabaseStructureValidator();
            $validator->validateAll();
            
            // 步驟 2: 修復
            echo "\n--- 步驟 2: 修復資料庫結構 ---\n";
            $fixer = new DatabaseStructureFixer();
            $fixer->fixAll();
            
            // 步驟 3: 生成報告
            echo "\n--- 步驟 3: 生成修復後報告 ---\n";
            $generator = new DatabaseReportGenerator();
            $generator->generateReport();
            
            echo "\n✅ 完整檢查和修復完成！\n";
        } catch (Exception $e) {
            echo "操作失敗: " . $e->getMessage() . "\n";
        }
        
        echo "\n按 Enter 鍵繼續...";
        fgets(STDIN);
        $this->showMenu();
    }
    
    private function showDatabaseStatus() {
        echo "\n=== 資料庫狀態 ===\n";
        
        try {
            $dbName = $this->getDatabaseName();
            echo "資料庫名稱: $dbName\n";
            
            // 獲取表格資訊
            $tables = $this->db->fetchAll("
                SELECT 
                    TABLE_NAME,
                    TABLE_ROWS,
                    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS size_mb
                FROM information_schema.tables 
                WHERE table_schema = DATABASE()
                ORDER BY TABLE_NAME
            ");
            
            echo "\n表格列表:\n";
            echo str_pad("表格名稱", 25) . str_pad("記錄數", 10) . str_pad("大小(MB)", 10) . "\n";
            echo str_repeat("-", 45) . "\n";
            
            $totalRows = 0;
            $totalSize = 0;
            
            foreach ($tables as $table) {
                echo str_pad($table['TABLE_NAME'], 25) . 
                     str_pad($table['TABLE_ROWS'], 10) . 
                     str_pad($table['size_mb'], 10) . "\n";
                $totalRows += $table['TABLE_ROWS'];
                $totalSize += $table['size_mb'];
            }
            
            echo str_repeat("-", 45) . "\n";
            echo str_pad("總計", 25) . str_pad($totalRows, 10) . str_pad(round($totalSize, 2), 10) . "\n";
            
            // 獲取外鍵數量
            $fkCount = $this->db->fetch("
                SELECT COUNT(*) as count 
                FROM information_schema.key_column_usage 
                WHERE table_schema = DATABASE() 
                AND referenced_table_name IS NOT NULL
            ");
            
            // 獲取索引數量
            $indexCount = $this->db->fetch("
                SELECT COUNT(*) as count 
                FROM information_schema.statistics 
                WHERE table_schema = DATABASE() 
                AND index_name != 'PRIMARY'
            ");
            
            echo "\n外鍵關係: " . $fkCount['count'] . " 個\n";
            echo "索引數量: " . $indexCount['count'] . " 個\n";
            
        } catch (Exception $e) {
            echo "獲取狀態失敗: " . $e->getMessage() . "\n";
        }
        
        echo "\n按 Enter 鍵繼續...";
        fgets(STDIN);
        $this->showMenu();
    }
    
    private function backupStructure() {
        echo "\n=== 備份資料庫結構 ===\n";
        
        try {
            $backupDir = __DIR__ . '/backups';
            if (!is_dir($backupDir)) {
                mkdir($backupDir, 0755, true);
            }
            
            $timestamp = date('Y-m-d_H-i-s');
            $filename = $backupDir . '/structure_backup_' . $timestamp . '.sql';
            
            // 獲取所有表格的 CREATE TABLE 語句
            $tables = $this->db->fetchAll("
                SELECT TABLE_NAME 
                FROM information_schema.tables 
                WHERE table_schema = DATABASE()
                ORDER BY TABLE_NAME
            ");
            
            $backupContent = "-- 資料庫結構備份\n";
            $backupContent .= "-- 生成時間: " . date('Y-m-d H:i:s') . "\n";
            $backupContent .= "-- 資料庫: " . $this->getDatabaseName() . "\n\n";
            
            foreach ($tables as $table) {
                $tableName = $table['TABLE_NAME'];
                
                // 獲取 CREATE TABLE 語句
                $createTable = $this->db->fetch("SHOW CREATE TABLE `$tableName`");
                $backupContent .= "-- 表格: $tableName\n";
                $backupContent .= $createTable['Create Table'] . ";\n\n";
            }
            
            file_put_contents($filename, $backupContent);
            echo "✅ 結構備份已保存到: $filename\n";
            
        } catch (Exception $e) {
            echo "備份失敗: " . $e->getMessage() . "\n";
        }
        
        echo "\n按 Enter 鍵繼續...";
        fgets(STDIN);
        $this->showMenu();
    }
    
    private function getDatabaseName() {
        $result = $this->db->fetch("SELECT DATABASE() as db_name");
        return $result['db_name'];
    }
}

// 檢查是否為命令列執行
if (php_sapi_name() === 'cli') {
    $manager = new DatabaseManager();
    $manager->showMenu();
} else {
    echo "此腳本僅支援命令列執行。\n";
    echo "使用方法: php database_manager.php\n";
}
?> 