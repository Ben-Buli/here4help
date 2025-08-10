<?php
/**
 * 資料庫結構驗證腳本
 * 檢查所有重要表格的結構、索引和外鍵關係
 */

require_once '../config/database.php';

class DatabaseStructureValidator {
    private $db;
    private $errors = [];
    private $warnings = [];
    private $success = [];
    
    public function __construct() {
        $this->db = Database::getInstance();
    }
    
    public function validateAll() {
        echo "=== 資料庫結構驗證開始 ===\n";
        echo "資料庫: " . $this->getDatabaseName() . "\n\n";
        
        // 檢查核心表格
        $this->validateUsersTable();
        $this->validateTasksTable();
        $this->validateTaskStatusesTable();
        $this->validateChatTables();
        $this->validateTaskApplicationsTable();
        
        // 檢查外鍵關係
        $this->validateForeignKeys();
        
        // 檢查索引
        $this->validateIndexes();
        
        // 輸出結果
        $this->printResults();
    }
    
    private function getDatabaseName() {
        $result = $this->db->fetch("SELECT DATABASE() as db_name");
        return $result['db_name'];
    }
    
    private function validateUsersTable() {
        echo "檢查 users 表格...\n";
        
        $columns = $this->db->fetchAll("
            SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND TABLE_NAME = 'users'
            ORDER BY ORDINAL_POSITION
        ");
        
        if (empty($columns)) {
            $this->errors[] = "users 表格不存在";
            return;
        }
        
        $requiredColumns = [
            'id' => 'BIGINT',
            'username' => 'VARCHAR',
            'email' => 'VARCHAR',
            'password' => 'VARCHAR',
            'created_at' => 'DATETIME'
        ];
        
        foreach ($requiredColumns as $col => $type) {
            $found = false;
            foreach ($columns as $column) {
                if ($column['COLUMN_NAME'] === $col) {
                    $found = true;
                    if (strpos($column['DATA_TYPE'], $type) === false) {
                        $this->warnings[] = "users.$col 欄位類型為 {$column['DATA_TYPE']}，預期為 $type";
                    }
                    break;
                }
            }
            if (!$found) {
                $this->errors[] = "users 表格缺少必要欄位: $col";
            }
        }
        
        $this->success[] = "users 表格結構檢查完成";
    }
    
    private function validateTasksTable() {
        echo "檢查 tasks 表格...\n";
        
        $columns = $this->db->fetchAll("
            SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND TABLE_NAME = 'tasks'
            ORDER BY ORDINAL_POSITION
        ");
        
        if (empty($columns)) {
            $this->errors[] = "tasks 表格不存在";
            return;
        }
        
        $requiredColumns = [
            'id' => 'BIGINT',
            'title' => 'VARCHAR',
            'description' => 'TEXT',
            'creator_id' => 'BIGINT',
            'status_id' => 'BIGINT',
            'created_at' => 'DATETIME'
        ];
        
        foreach ($requiredColumns as $col => $type) {
            $found = false;
            foreach ($columns as $column) {
                if ($column['COLUMN_NAME'] === $col) {
                    $found = true;
                    if (strpos($column['DATA_TYPE'], $type) === false) {
                        $this->warnings[] = "tasks.$col 欄位類型為 {$column['DATA_TYPE']}，預期為 $type";
                    }
                    break;
                }
            }
            if (!$found) {
                $this->errors[] = "tasks 表格缺少必要欄位: $col";
            }
        }
        
        $this->success[] = "tasks 表格結構檢查完成";
    }
    
    private function validateTaskStatusesTable() {
        echo "檢查 task_statuses 表格...\n";
        
        $columns = $this->db->fetchAll("
            SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND TABLE_NAME = 'task_statuses'
            ORDER BY ORDINAL_POSITION
        ");
        
        if (empty($columns)) {
            $this->errors[] = "task_statuses 表格不存在";
            return;
        }
        
        // 檢查狀態資料
        $statuses = $this->db->fetchAll("SELECT * FROM task_statuses");
        $expectedStatuses = ['open', 'in_progress', 'completed', 'cancelled'];
        
        foreach ($expectedStatuses as $status) {
            $found = false;
            foreach ($statuses as $row) {
                if ($row['name'] === $status) {
                    $found = true;
                    break;
                }
            }
            if (!$found) {
                $this->warnings[] = "缺少預期狀態: $status";
            }
        }
        
        $this->success[] = "task_statuses 表格結構檢查完成";
    }
    
    private function validateChatTables() {
        echo "檢查聊天相關表格...\n";
        
        // 檢查 chat_rooms
        $chatRooms = $this->db->fetchAll("
            SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND TABLE_NAME = 'chat_rooms'
            ORDER BY ORDINAL_POSITION
        ");
        
        if (empty($chatRooms)) {
            $this->errors[] = "chat_rooms 表格不存在";
        } else {
            $this->success[] = "chat_rooms 表格存在";
        }
        
        // 檢查 chat_messages
        $chatMessages = $this->db->fetchAll("
            SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND TABLE_NAME = 'chat_messages'
            ORDER BY ORDINAL_POSITION
        ");
        
        if (empty($chatMessages)) {
            $this->errors[] = "chat_messages 表格不存在";
        } else {
            // 檢查必要欄位
            $requiredFields = ['id', 'room_id', 'from_user_id', 'message', 'created_at'];
            foreach ($requiredFields as $field) {
                $found = false;
                foreach ($chatMessages as $col) {
                    if ($col['COLUMN_NAME'] === $field) {
                        $found = true;
                        break;
                    }
                }
                if (!$found) {
                    $this->errors[] = "chat_messages 缺少欄位: $field";
                }
            }
            $this->success[] = "chat_messages 表格結構檢查完成";
        }
        
        // 檢查 chat_reads
        $chatReads = $this->db->fetchAll("
            SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND TABLE_NAME = 'chat_reads'
            ORDER BY ORDINAL_POSITION
        ");
        
        if (empty($chatReads)) {
            $this->errors[] = "chat_reads 表格不存在";
        } else {
            $this->success[] = "chat_reads 表格存在";
        }
    }
    
    private function validateTaskApplicationsTable() {
        echo "檢查 task_applications 表格...\n";
        
        $columns = $this->db->fetchAll("
            SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND TABLE_NAME = 'task_applications'
            ORDER BY ORDINAL_POSITION
        ");
        
        if (empty($columns)) {
            $this->warnings[] = "task_applications 表格不存在（可能尚未創建）";
            return;
        }
        
        $requiredColumns = [
            'id' => 'BIGINT',
            'task_id' => 'BIGINT',
            'applicant_id' => 'BIGINT',
            'status' => 'VARCHAR',
            'created_at' => 'DATETIME'
        ];
        
        foreach ($requiredColumns as $col => $type) {
            $found = false;
            foreach ($columns as $column) {
                if ($column['COLUMN_NAME'] === $col) {
                    $found = true;
                    break;
                }
            }
            if (!$found) {
                $this->warnings[] = "task_applications 表格缺少欄位: $col";
            }
        }
        
        $this->success[] = "task_applications 表格結構檢查完成";
    }
    
    private function validateForeignKeys() {
        echo "檢查外鍵關係...\n";
        
        $foreignKeys = $this->db->fetchAll("
            SELECT 
                TABLE_NAME,
                COLUMN_NAME,
                CONSTRAINT_NAME,
                REFERENCED_TABLE_NAME,
                REFERENCED_COLUMN_NAME
            FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND REFERENCED_TABLE_NAME IS NOT NULL
            ORDER BY TABLE_NAME, COLUMN_NAME
        ");
        
        if (empty($foreignKeys)) {
            $this->warnings[] = "沒有找到外鍵約束";
        } else {
            foreach ($foreignKeys as $fk) {
                $this->success[] = "外鍵: {$fk['TABLE_NAME']}.{$fk['COLUMN_NAME']} -> {$fk['REFERENCED_TABLE_NAME']}.{$fk['REFERENCED_COLUMN_NAME']}";
            }
        }
    }
    
    private function validateIndexes() {
        echo "檢查索引...\n";
        
        $indexes = $this->db->fetchAll("
            SELECT 
                TABLE_NAME,
                INDEX_NAME,
                COLUMN_NAME,
                NON_UNIQUE
            FROM INFORMATION_SCHEMA.STATISTICS 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND INDEX_NAME != 'PRIMARY'
            ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX
        ");
        
        if (empty($indexes)) {
            $this->warnings[] = "沒有找到非主鍵索引";
        } else {
            foreach ($indexes as $index) {
                $type = $index['NON_UNIQUE'] ? 'INDEX' : 'UNIQUE';
                $this->success[] = "索引: {$index['TABLE_NAME']}.{$index['INDEX_NAME']} ({$index['COLUMN_NAME']}) - $type";
            }
        }
    }
    
    private function printResults() {
        echo "\n=== 驗證結果 ===\n";
        
        if (!empty($this->success)) {
            echo "\n✅ 成功項目:\n";
            foreach ($this->success as $msg) {
                echo "  - $msg\n";
            }
        }
        
        if (!empty($this->warnings)) {
            echo "\n⚠️  警告:\n";
            foreach ($this->warnings as $msg) {
                echo "  - $msg\n";
            }
        }
        
        if (!empty($this->errors)) {
            echo "\n❌ 錯誤:\n";
            foreach ($this->errors as $msg) {
                echo "  - $msg\n";
            }
        }
        
        echo "\n=== 驗證完成 ===\n";
        
        if (empty($this->errors)) {
            echo "✅ 資料庫結構驗證通過！\n";
        } else {
            echo "❌ 發現 " . count($this->errors) . " 個錯誤需要修復\n";
        }
    }
}

// 執行驗證
try {
    $validator = new DatabaseStructureValidator();
    $validator->validateAll();
} catch (Exception $e) {
    echo "驗證過程中發生錯誤: " . $e->getMessage() . "\n";
}
?> 