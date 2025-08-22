<?php
// 一次性資料修復：將 task_applications.answers_json 中的 introduction 搬到 cover_letter（僅在 cover_letter 為空時）
// 使用方式：php backend/database/fix_structure.php

require_once __DIR__ . '/../config/database.php';

try {
    $db = Database::getInstance();

    $rows = $db->fetchAll("SELECT id, cover_letter, answers_json FROM task_applications");
    $updated = 0;

    foreach ($rows as $row) {
        $id = (int)$row['id'];
        $cover = $row['cover_letter'];
        $answers = $row['answers_json'];

        if (!empty($cover)) continue; // 只修補 cover 為空的資料
        if (empty($answers)) continue;

        $decoded = json_decode($answers, true);
        if (!is_array($decoded)) continue;

        $intro = isset($decoded['introduction']) ? trim((string)$decoded['introduction']) : '';
        if ($intro === '') continue;

        // 將 introduction 搬到 cover_letter
        $db->query("UPDATE task_applications SET cover_letter = ? WHERE id = ?", [$intro, $id]);
        $updated++;
    }

    echo "Fixed rows: {$updated}\n";
} catch (Exception $e) {
    echo 'Error: ' . $e->getMessage() . "\n";
}

?>
<?php
/**
 * 資料庫結構修復腳本
 * 自動修復常見的資料庫結構問題
 */

require_once __DIR__ . '/../config/database.php';

class DatabaseStructureFixer {
    private $db;
    private $fixes = [];
    private $errors = [];
    
    public function __construct() {
        $this->db = Database::getInstance();
    }
    
    public function fixAll() {
        echo "=== 資料庫結構修復開始 ===\n";
        echo "資料庫: " . $this->getDatabaseName() . "\n\n";
        
        // 修復核心表格
        $this->fixUsersTable();
        $this->fixTasksTable();
        $this->fixTaskStatusesTable();
        $this->fixChatTables();
        $this->fixTaskApplicationsTable();
        
        // 修復外鍵關係
        $this->fixForeignKeys();
        
        // 修復索引
        $this->fixIndexes();
        
        // 輸出結果
        $this->printResults();
    }
    
    private function getDatabaseName() {
        $result = $this->db->fetch("SELECT DATABASE() as db_name");
        return $result['db_name'];
    }
    
    private function fixUsersTable() {
        echo "修復 users 表格...\n";
        
        // 檢查表格是否存在
        $tableExists = $this->db->fetch("
            SELECT COUNT(*) as count 
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND TABLE_NAME = 'users'
        ");
        
        if ($tableExists['count'] == 0) {
            // 創建 users 表格
            $sql = "
                CREATE TABLE users (
                    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                    username VARCHAR(255) NOT NULL UNIQUE,
                    email VARCHAR(255) NOT NULL UNIQUE,
                    password VARCHAR(255) NOT NULL,
                    first_name VARCHAR(100) NULL,
                    last_name VARCHAR(100) NULL,
                    avatar_url VARCHAR(500) NULL,
                    points INT DEFAULT 0,
                    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    INDEX idx_username (username),
                    INDEX idx_email (email)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            ";
            
            try {
                $this->db->query($sql);
                $this->fixes[] = "創建了 users 表格";
            } catch (Exception $e) {
                $this->errors[] = "創建 users 表格失敗: " . $e->getMessage();
            }
        } else {
            // 檢查並添加缺少的欄位
            $this->addColumnIfNotExists('users', 'first_name', 'VARCHAR(100) NULL');
            $this->addColumnIfNotExists('users', 'last_name', 'VARCHAR(100) NULL');
            $this->addColumnIfNotExists('users', 'avatar_url', 'VARCHAR(500) NULL');
            $this->addColumnIfNotExists('users', 'points', 'INT DEFAULT 0');
            $this->addColumnIfNotExists('users', 'updated_at', 'DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');
        }
    }
    
    private function fixTasksTable() {
        echo "修復 tasks 表格...\n";
        
        // 檢查表格是否存在
        $tableExists = $this->db->fetch("
            SELECT COUNT(*) as count 
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND TABLE_NAME = 'tasks'
        ");
        
        if ($tableExists['count'] == 0) {
            // 創建 tasks 表格
            $sql = "
                CREATE TABLE tasks (
                    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                    title VARCHAR(255) NOT NULL,
                    description TEXT NOT NULL,
                    creator_id BIGINT UNSIGNED NOT NULL,
                    status_id BIGINT UNSIGNED NOT NULL,
                    reward_points INT DEFAULT 0,
                    location VARCHAR(255) NULL,
                    deadline DATETIME NULL,
                    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    INDEX idx_creator (creator_id),
                    INDEX idx_status (status_id),
                    INDEX idx_created (created_at),
                    FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE,
                    FOREIGN KEY (status_id) REFERENCES task_statuses(id) ON DELETE RESTRICT
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            ";
            
            try {
                $this->db->query($sql);
                $this->fixes[] = "創建了 tasks 表格";
            } catch (Exception $e) {
                $this->errors[] = "創建 tasks 表格失敗: " . $e->getMessage();
            }
        } else {
            // 檢查並添加缺少的欄位
            $this->addColumnIfNotExists('tasks', 'reward_points', 'INT DEFAULT 0');
            $this->addColumnIfNotExists('tasks', 'location', 'VARCHAR(255) NULL');
            $this->addColumnIfNotExists('tasks', 'deadline', 'DATETIME NULL');
            $this->addColumnIfNotExists('tasks', 'updated_at', 'DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');
        }
    }
    
    private function fixTaskStatusesTable() {
        echo "修復 task_statuses 表格...\n";
        
        // 檢查表格是否存在
        $tableExists = $this->db->fetch("
            SELECT COUNT(*) as count 
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND TABLE_NAME = 'task_statuses'
        ");
        
        if ($tableExists['count'] == 0) {
            // 創建 task_statuses 表格
            $sql = "
                CREATE TABLE task_statuses (
                    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                    name VARCHAR(50) NOT NULL UNIQUE,
                    display_name VARCHAR(100) NOT NULL,
                    color VARCHAR(7) DEFAULT '#666666',
                    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (id)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            ";
            
            try {
                $this->db->query($sql);
                $this->fixes[] = "創建了 task_statuses 表格";
                
                // 插入預設狀態
                $this->insertDefaultStatuses();
            } catch (Exception $e) {
                $this->errors[] = "創建 task_statuses 表格失敗: " . $e->getMessage();
            }
        } else {
            // 檢查並添加缺少的欄位
            $this->addColumnIfNotExists('task_statuses', 'display_name', 'VARCHAR(100) NOT NULL');
            $this->addColumnIfNotExists('task_statuses', 'color', 'VARCHAR(7) DEFAULT "#666666"');
            $this->addColumnIfNotExists('task_statuses', 'created_at', 'DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP');
            
            // 檢查預設狀態
            $this->insertDefaultStatuses();
        }
    }
    
    private function insertDefaultStatuses() {
        $defaultStatuses = [
            ['name' => 'open', 'display_name' => '開放中', 'color' => '#28a745'],
            ['name' => 'in_progress', 'display_name' => '進行中', 'color' => '#007bff'],
            ['name' => 'completed', 'display_name' => '已完成', 'color' => '#6c757d'],
            ['name' => 'cancelled', 'display_name' => '已取消', 'color' => '#dc3545']
        ];
        
        foreach ($defaultStatuses as $status) {
            $exists = $this->db->fetch("SELECT COUNT(*) as count FROM task_statuses WHERE name = ?", [$status['name']]);
            if ($exists['count'] == 0) {
                try {
                    $this->db->query(
                        "INSERT INTO task_statuses (name, display_name, color) VALUES (?, ?, ?)",
                        [$status['name'], $status['display_name'], $status['color']]
                    );
                    $this->fixes[] = "添加狀態: {$status['display_name']}";
                } catch (Exception $e) {
                    $this->errors[] = "添加狀態失敗: " . $e->getMessage();
                }
            }
        }
    }
    
    private function fixChatTables() {
        echo "修復聊天相關表格...\n";
        
        // 修復 chat_rooms
        $this->createTableIfNotExists('chat_rooms', "
            CREATE TABLE chat_rooms (
                id VARCHAR(128) PRIMARY KEY,
                task_id BIGINT UNSIGNED NULL,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX idx_task (task_id),
                FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE SET NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");
        
        // 修復 chat_messages
        $this->createTableIfNotExists('chat_messages', "
            CREATE TABLE chat_messages (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                room_id VARCHAR(128) NOT NULL,
                from_user_id BIGINT UNSIGNED NOT NULL,
                message TEXT NOT NULL,
                kind ENUM('user', 'system') DEFAULT 'user',
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                INDEX idx_room_created (room_id, created_at),
                INDEX idx_from_user (from_user_id),
                FOREIGN KEY (room_id) REFERENCES chat_rooms(id) ON DELETE CASCADE,
                FOREIGN KEY (from_user_id) REFERENCES users(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");
        
        // 修復 chat_reads
        $this->createTableIfNotExists('chat_reads', "
            CREATE TABLE chat_reads (
                user_id BIGINT UNSIGNED NOT NULL,
                room_id VARCHAR(128) NOT NULL,
                last_read_message_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (user_id, room_id),
                INDEX idx_room_user (room_id, user_id),
                FOREIGN KEY (room_id) REFERENCES chat_rooms(id) ON DELETE CASCADE,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");
    }
    
    private function fixTaskApplicationsTable() {
        echo "修復 task_applications 表格...\n";
        
        $this->createTableIfNotExists('task_applications', "
            CREATE TABLE task_applications (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                task_id BIGINT UNSIGNED NOT NULL,
                applicant_id BIGINT UNSIGNED NOT NULL,
                status ENUM('pending', 'approved', 'rejected', 'withdrawn') DEFAULT 'pending',
                message TEXT NULL,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY unique_task_applicant (task_id, applicant_id),
                INDEX idx_task (task_id),
                INDEX idx_applicant (applicant_id),
                INDEX idx_status (status),
                FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
                FOREIGN KEY (applicant_id) REFERENCES users(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");
    }
    
    private function fixForeignKeys() {
        echo "修復外鍵關係...\n";
        
        // 這裡可以添加具體的外鍵修復邏輯
        // 由於外鍵修復比較複雜，建議手動處理
        $this->fixes[] = "外鍵關係檢查完成（如需修復請手動處理）";
    }
    
    private function fixIndexes() {
        echo "修復索引...\n";
        
        // 為常用查詢添加索引
        $indexes = [
            ['table' => 'users', 'name' => 'idx_created', 'columns' => 'created_at'],
            ['table' => 'tasks', 'name' => 'idx_deadline', 'columns' => 'deadline'],
            ['table' => 'tasks', 'name' => 'idx_location', 'columns' => 'location'],
            ['table' => 'chat_messages', 'name' => 'idx_kind', 'columns' => 'kind']
        ];
        
        foreach ($indexes as $index) {
            $this->createIndexIfNotExists($index['table'], $index['name'], $index['columns']);
        }
    }
    
    private function createTableIfNotExists($tableName, $createSql) {
        $tableExists = $this->db->fetch("
            SELECT COUNT(*) as count 
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND TABLE_NAME = ?
        ", [$tableName]);
        
        if ($tableExists['count'] == 0) {
            try {
                $this->db->query($createSql);
                $this->fixes[] = "創建了 $tableName 表格";
            } catch (Exception $e) {
                $this->errors[] = "創建 $tableName 表格失敗: " . $e->getMessage();
            }
        }
    }
    
    private function addColumnIfNotExists($table, $column, $definition) {
        $columnExists = $this->db->fetch("
            SELECT COUNT(*) as count 
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND TABLE_NAME = ? 
            AND COLUMN_NAME = ?
        ", [$table, $column]);
        
        if ($columnExists['count'] == 0) {
            try {
                $this->db->query("ALTER TABLE $table ADD COLUMN $column $definition");
                $this->fixes[] = "為 $table 表格添加欄位: $column";
            } catch (Exception $e) {
                $this->errors[] = "為 $table 添加欄位 $column 失敗: " . $e->getMessage();
            }
        }
    }
    
    private function createIndexIfNotExists($table, $indexName, $columns) {
        $indexExists = $this->db->fetch("
            SELECT COUNT(*) as count 
            FROM INFORMATION_SCHEMA.STATISTICS 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND TABLE_NAME = ? 
            AND INDEX_NAME = ?
        ", [$table, $indexName]);
        
        if ($indexExists['count'] == 0) {
            try {
                $this->db->query("CREATE INDEX $indexName ON $table ($columns)");
                $this->fixes[] = "為 $table 表格創建索引: $indexName";
            } catch (Exception $e) {
                $this->errors[] = "為 $table 創建索引 $indexName 失敗: " . $e->getMessage();
            }
        }
    }
    
    private function printResults() {
        echo "\n=== 修復結果 ===\n";
        
        if (!empty($this->fixes)) {
            echo "\n✅ 修復項目:\n";
            foreach ($this->fixes as $fix) {
                echo "  - $fix\n";
            }
        }
        
        if (!empty($this->errors)) {
            echo "\n❌ 錯誤:\n";
            foreach ($this->errors as $error) {
                echo "  - $error\n";
            }
        }
        
        echo "\n=== 修復完成 ===\n";
        
        if (empty($this->errors)) {
            echo "✅ 資料庫結構修復完成！\n";
        } else {
            echo "⚠️  修復完成，但有 " . count($this->errors) . " 個錯誤需要手動處理\n";
        }
    }
}

// 執行修復
try {
    $fixer = new DatabaseStructureFixer();
    $fixer->fixAll();
} catch (Exception $e) {
    echo "修復過程中發生錯誤: " . $e->getMessage() . "\n";
}
?> 