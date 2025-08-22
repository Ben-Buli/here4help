<?php
/**
 * 外鍵約束與索引最佳化工具
 * 檢查並補強資料庫約束和索引
 */

require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../utils/Logger.php';

class ConstraintOptimizer {
    private $db;
    private $issues = [];
    private $recommendations = [];
    
    public function __construct() {
        $this->db = Database::getInstance()->getConnection();
    }
    
    /**
     * 執行完整的約束和索引檢查
     */
    public function runFullAnalysis() {
        echo "🔍 開始外鍵約束與索引分析\n";
        echo "===========================\n\n";
        
        $this->checkForeignKeyConstraints();
        $this->checkMissingIndexes();
        $this->checkDuplicateIndexes();
        $this->checkUnusedIndexes();
        $this->analyzeQueryPerformance();
        $this->generateOptimizationPlan();
        $this->generateReport();
        
        return [
            'issues' => $this->issues,
            'recommendations' => $this->recommendations
        ];
    }
    
    /**
     * 檢查外鍵約束
     */
    private function checkForeignKeyConstraints() {
        echo "1. 檢查外鍵約束\n";
        echo "---------------\n";
        
        // 獲取所有外鍵約束
        $sql = "
            SELECT 
                kcu.TABLE_NAME,
                kcu.COLUMN_NAME,
                kcu.CONSTRAINT_NAME,
                kcu.REFERENCED_TABLE_NAME,
                kcu.REFERENCED_COLUMN_NAME,
                rc.UPDATE_RULE,
                rc.DELETE_RULE
            FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
            JOIN INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS rc 
                ON kcu.CONSTRAINT_NAME = rc.CONSTRAINT_NAME
                AND kcu.TABLE_SCHEMA = rc.CONSTRAINT_SCHEMA
            WHERE kcu.TABLE_SCHEMA = DATABASE()
            AND kcu.REFERENCED_TABLE_NAME IS NOT NULL
            ORDER BY kcu.TABLE_NAME, kcu.COLUMN_NAME
        ";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        $foreignKeys = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo "發現 " . count($foreignKeys) . " 個外鍵約束:\n";
        
        foreach ($foreignKeys as $fk) {
            $status = '✅';
            echo "$status {$fk['TABLE_NAME']}.{$fk['COLUMN_NAME']} -> {$fk['REFERENCED_TABLE_NAME']}.{$fk['REFERENCED_COLUMN_NAME']}\n";
            echo "   約束名稱: {$fk['CONSTRAINT_NAME']}\n";
            echo "   更新規則: {$fk['UPDATE_RULE']}, 刪除規則: {$fk['DELETE_RULE']}\n";
            
            // 檢查約束規則是否合適
            if ($fk['DELETE_RULE'] === 'CASCADE' && !in_array($fk['TABLE_NAME'], ['chat_messages', 'task_logs'])) {
                $this->issues[] = [
                    'type' => 'dangerous_cascade_delete',
                    'severity' => 'high',
                    'table' => $fk['TABLE_NAME'],
                    'column' => $fk['COLUMN_NAME'],
                    'constraint' => $fk['CONSTRAINT_NAME'],
                    'message' => "CASCADE DELETE 可能造成意外的數據刪除"
                ];
            }
            
            echo "\n";
        }
        
        // 檢查缺失的外鍵約束
        $this->checkMissingForeignKeys();
        
        echo "\n";
    }
    
    /**
     * 檢查缺失的外鍵約束
     */
    private function checkMissingForeignKeys() {
        echo "檢查可能缺失的外鍵約束:\n";
        
        // 定義應該有外鍵約束的欄位
        $expectedForeignKeys = [
            'tasks.creator_id' => 'users.id',
            'tasks.participant_id' => 'users.id',
            'tasks.status_id' => 'task_statuses.id',
            'task_applications.user_id' => 'users.id',
            'task_applications.task_id' => 'tasks.id',
            'chat_rooms.creator_id' => 'users.id',
            'chat_rooms.participant_id' => 'users.id',
            'chat_rooms.task_id' => 'tasks.id',
            'chat_messages.from_user_id' => 'users.id',
            'chat_messages.room_id' => 'chat_rooms.id',
            'user_identities.user_id' => 'users.id',
            'task_logs.user_id' => 'users.id',
            'task_logs.task_id' => 'tasks.id',
        ];
        
        // 獲取現有的外鍵約束
        $existingFKs = [];
        $sql = "
            SELECT CONCAT(TABLE_NAME, '.', COLUMN_NAME) as fk_key
            FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
            WHERE TABLE_SCHEMA = DATABASE()
            AND REFERENCED_TABLE_NAME IS NOT NULL
        ";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        $existing = $stmt->fetchAll(PDO::FETCH_COLUMN);
        
        foreach ($existing as $fk) {
            $existingFKs[$fk] = true;
        }
        
        foreach ($expectedForeignKeys as $fkColumn => $refColumn) {
            if (!isset($existingFKs[$fkColumn])) {
                list($table, $column) = explode('.', $fkColumn);
                list($refTable, $refCol) = explode('.', $refColumn);
                
                // 檢查欄位是否存在
                if ($this->columnExists($table, $column) && $this->columnExists($refTable, $refCol)) {
                    echo "⚠️  缺失外鍵: $fkColumn -> $refColumn\n";
                    
                    $this->issues[] = [
                        'type' => 'missing_foreign_key',
                        'severity' => 'medium',
                        'table' => $table,
                        'column' => $column,
                        'referenced_table' => $refTable,
                        'referenced_column' => $refCol,
                        'message' => "缺失外鍵約束"
                    ];
                }
            }
        }
    }
    
    /**
     * 檢查缺失的索引
     */
    private function checkMissingIndexes() {
        echo "2. 檢查缺失的索引\n";
        echo "-----------------\n";
        
        // 獲取所有外鍵欄位
        $sql = "
            SELECT 
                TABLE_NAME,
                COLUMN_NAME
            FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
            WHERE TABLE_SCHEMA = DATABASE()
            AND REFERENCED_TABLE_NAME IS NOT NULL
        ";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        $foreignKeyColumns = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // 獲取現有索引
        $existingIndexes = $this->getExistingIndexes();
        
        foreach ($foreignKeyColumns as $fkCol) {
            $indexKey = $fkCol['TABLE_NAME'] . '.' . $fkCol['COLUMN_NAME'];
            
            if (!isset($existingIndexes[$indexKey])) {
                echo "⚠️  外鍵欄位缺少索引: {$fkCol['TABLE_NAME']}.{$fkCol['COLUMN_NAME']}\n";
                
                $this->issues[] = [
                    'type' => 'missing_foreign_key_index',
                    'severity' => 'medium',
                    'table' => $fkCol['TABLE_NAME'],
                    'column' => $fkCol['COLUMN_NAME'],
                    'message' => "外鍵欄位缺少索引，可能影響查詢性能"
                ];
            } else {
                echo "✅ {$fkCol['TABLE_NAME']}.{$fkCol['COLUMN_NAME']} 已有索引\n";
            }
        }
        
        // 檢查常用查詢欄位的索引
        $this->checkCommonQueryIndexes();
        
        echo "\n";
    }
    
    /**
     * 檢查常用查詢欄位的索引
     */
    private function checkCommonQueryIndexes() {
        echo "\n檢查常用查詢欄位索引:\n";
        
        $commonQueryColumns = [
            'users.email' => '用戶登錄查詢',
            'users.status' => '用戶狀態篩選',
            'tasks.status_id' => '任務狀態篩選',
            'tasks.created_at' => '任務時間排序',
            'chat_messages.created_at' => '訊息時間排序',
            'task_applications.status' => '申請狀態篩選',
            'task_logs.created_at' => '日誌時間查詢',
        ];
        
        $existingIndexes = $this->getExistingIndexes();
        
        foreach ($commonQueryColumns as $column => $description) {
            if (!isset($existingIndexes[$column])) {
                list($table, $col) = explode('.', $column);
                
                if ($this->columnExists($table, $col)) {
                    echo "⚠️  建議添加索引: $column ($description)\n";
                    
                    $this->issues[] = [
                        'type' => 'missing_query_index',
                        'severity' => 'low',
                        'table' => $table,
                        'column' => $col,
                        'description' => $description,
                        'message' => "常用查詢欄位建議添加索引"
                    ];
                }
            } else {
                echo "✅ $column 已有索引\n";
            }
        }
    }
    
    /**
     * 檢查重複索引
     */
    private function checkDuplicateIndexes() {
        echo "3. 檢查重複索引\n";
        echo "---------------\n";
        
        $sql = "
            SELECT 
                TABLE_NAME,
                INDEX_NAME,
                GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) as columns,
                MAX(NON_UNIQUE) as NON_UNIQUE
            FROM INFORMATION_SCHEMA.STATISTICS 
            WHERE TABLE_SCHEMA = DATABASE()
            AND INDEX_NAME != 'PRIMARY'
            GROUP BY TABLE_NAME, INDEX_NAME
            ORDER BY TABLE_NAME, INDEX_NAME
        ";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        $indexes = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // 按表格分組檢查重複
        $indexesByTable = [];
        foreach ($indexes as $index) {
            $indexesByTable[$index['TABLE_NAME']][] = $index;
        }
        
        $duplicateCount = 0;
        
        foreach ($indexesByTable as $table => $tableIndexes) {
            $columnGroups = [];
            
            foreach ($tableIndexes as $index) {
                $columns = $index['columns'];
                
                if (isset($columnGroups[$columns])) {
                    echo "⚠️  發現重複索引: {$table}.{$index['INDEX_NAME']} 與 {$columnGroups[$columns]} (欄位: $columns)\n";
                    
                    $this->issues[] = [
                        'type' => 'duplicate_index',
                        'severity' => 'low',
                        'table' => $table,
                        'index1' => $index['INDEX_NAME'],
                        'index2' => $columnGroups[$columns],
                        'columns' => $columns,
                        'message' => "重複索引浪費存儲空間"
                    ];
                    
                    $duplicateCount++;
                } else {
                    $columnGroups[$columns] = $index['INDEX_NAME'];
                }
            }
        }
        
        if ($duplicateCount === 0) {
            echo "✅ 沒有發現重複索引\n";
        }
        
        echo "\n";
    }
    
    /**
     * 檢查未使用的索引（簡化版本）
     */
    private function checkUnusedIndexes() {
        echo "4. 檢查可能未使用的索引\n";
        echo "---------------------\n";
        
        // 這是一個簡化的檢查，實際環境中需要分析查詢日誌
        $sql = "
            SELECT 
                TABLE_NAME,
                INDEX_NAME,
                GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) as columns
            FROM INFORMATION_SCHEMA.STATISTICS 
            WHERE TABLE_SCHEMA = DATABASE()
            AND INDEX_NAME != 'PRIMARY'
            AND NON_UNIQUE = 1
            GROUP BY TABLE_NAME, INDEX_NAME
            ORDER BY TABLE_NAME, INDEX_NAME
        ";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        $indexes = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // 簡單的啟發式檢查
        $suspiciousIndexes = [];
        
        foreach ($indexes as $index) {
            // 檢查是否是單欄位索引且欄位名稱不常見
            $columns = explode(',', $index['columns']);
            
            if (count($columns) === 1) {
                $column = trim($columns[0]);
                
                // 如果不是常見的查詢欄位，標記為可疑
                if (!in_array($column, ['created_at', 'updated_at', 'status', 'user_id', 'task_id', 'email'])) {
                    $suspiciousIndexes[] = $index;
                }
            }
        }
        
        if (empty($suspiciousIndexes)) {
            echo "✅ 沒有發現明顯未使用的索引\n";
        } else {
            echo "發現 " . count($suspiciousIndexes) . " 個可能未使用的索引:\n";
            foreach ($suspiciousIndexes as $index) {
                echo "⚠️  {$index['TABLE_NAME']}.{$index['INDEX_NAME']} (欄位: {$index['columns']})\n";
            }
            echo "\n建議: 分析查詢日誌確認這些索引是否真的未使用\n";
        }
        
        echo "\n";
    }
    
    /**
     * 分析查詢性能
     */
    private function analyzeQueryPerformance() {
        echo "5. 分析查詢性能\n";
        echo "---------------\n";
        
        // 檢查表格大小和索引效率
        $sql = "
            SELECT 
                TABLE_NAME,
                TABLE_ROWS,
                DATA_LENGTH,
                INDEX_LENGTH,
                ROUND(INDEX_LENGTH / DATA_LENGTH, 2) as index_ratio
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_SCHEMA = DATABASE()
            AND TABLE_TYPE = 'BASE TABLE'
            AND TABLE_ROWS > 0
            ORDER BY TABLE_ROWS DESC
        ";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        $tables = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo "表格大小和索引分析:\n";
        
        foreach ($tables as $table) {
            $dataSize = $this->formatBytes($table['DATA_LENGTH']);
            $indexSize = $this->formatBytes($table['INDEX_LENGTH']);
            $ratio = $table['index_ratio'] ?? 0;
            
            echo "- {$table['TABLE_NAME']}: {$table['TABLE_ROWS']} 筆記錄, 數據: $dataSize, 索引: $indexSize";
            
            if ($ratio > 2) {
                echo " ⚠️  索引過大 (比例: {$ratio}:1)";
                
                $this->issues[] = [
                    'type' => 'oversized_indexes',
                    'severity' => 'low',
                    'table' => $table['TABLE_NAME'],
                    'ratio' => $ratio,
                    'message' => "索引大小相對於數據過大，可能有冗餘索引"
                ];
            } elseif ($ratio < 0.1 && $table['TABLE_ROWS'] > 1000) {
                echo " ⚠️  索引可能不足 (比例: {$ratio}:1)";
                
                $this->issues[] = [
                    'type' => 'insufficient_indexes',
                    'severity' => 'medium',
                    'table' => $table['TABLE_NAME'],
                    'ratio' => $ratio,
                    'message' => "大表缺少足夠的索引，可能影響查詢性能"
                ];
            } else {
                echo " ✅";
            }
            
            echo "\n";
        }
        
        echo "\n";
    }
    
    /**
     * 生成最佳化計劃
     */
    private function generateOptimizationPlan() {
        echo "6. 生成最佳化計劃\n";
        echo "-----------------\n";
        
        $optimizations = [];
        
        foreach ($this->issues as $issue) {
            switch ($issue['type']) {
                case 'missing_foreign_key':
                    $optimizations[] = [
                        'priority' => 2,
                        'action' => 'ADD_FOREIGN_KEY',
                        'table' => $issue['table'],
                        'sql' => "ALTER TABLE `{$issue['table']}` ADD CONSTRAINT `fk_{$issue['table']}_{$issue['column']}` FOREIGN KEY (`{$issue['column']}`) REFERENCES `{$issue['referenced_table']}`(`{$issue['referenced_column']}`) ON DELETE RESTRICT ON UPDATE CASCADE;",
                        'risk' => 'medium',
                        'description' => "添加外鍵約束: {$issue['table']}.{$issue['column']}"
                    ];
                    break;
                    
                case 'missing_foreign_key_index':
                    $optimizations[] = [
                        'priority' => 1,
                        'action' => 'ADD_INDEX',
                        'table' => $issue['table'],
                        'sql' => "CREATE INDEX `idx_{$issue['table']}_{$issue['column']}` ON `{$issue['table']}`(`{$issue['column']}`);",
                        'risk' => 'low',
                        'description' => "為外鍵欄位添加索引: {$issue['table']}.{$issue['column']}"
                    ];
                    break;
                    
                case 'missing_query_index':
                    $optimizations[] = [
                        'priority' => 3,
                        'action' => 'ADD_INDEX',
                        'table' => $issue['table'],
                        'sql' => "CREATE INDEX `idx_{$issue['table']}_{$issue['column']}` ON `{$issue['table']}`(`{$issue['column']}`);",
                        'risk' => 'low',
                        'description' => "為常用查詢欄位添加索引: {$issue['table']}.{$issue['column']}"
                    ];
                    break;
                    
                case 'duplicate_index':
                    $optimizations[] = [
                        'priority' => 4,
                        'action' => 'DROP_INDEX',
                        'table' => $issue['table'],
                        'sql' => "DROP INDEX `{$issue['index2']}` ON `{$issue['table']}`;",
                        'risk' => 'low',
                        'description' => "刪除重複索引: {$issue['table']}.{$issue['index2']}"
                    ];
                    break;
            }
        }
        
        // 按優先級排序
        usort($optimizations, function($a, $b) {
            return $a['priority'] - $b['priority'];
        });
        
        $this->recommendations = $optimizations;
        
        if (empty($optimizations)) {
            echo "✅ 沒有發現需要最佳化的項目\n\n";
            return;
        }
        
        echo "建議的最佳化步驟:\n";
        foreach ($optimizations as $i => $opt) {
            $riskColor = $opt['risk'] === 'high' ? '🔴' : ($opt['risk'] === 'medium' ? '🟡' : '🟢');
            echo ($i + 1) . ". $riskColor {$opt['description']}\n";
            echo "   SQL: {$opt['sql']}\n";
            echo "   風險: {$opt['risk']}\n\n";
        }
    }
    
    /**
     * 生成詳細報告
     */
    private function generateReport() {
        echo "7. 生成分析報告\n";
        echo "---------------\n";
        
        $reportDir = __DIR__ . '/reports';
        if (!is_dir($reportDir)) {
            mkdir($reportDir, 0755, true);
        }
        
        $reportFile = $reportDir . '/constraint_optimization_' . date('Y-m-d_H-i-s') . '.json';
        
        $report = [
            'analysis_date' => date('Y-m-d H:i:s'),
            'database' => $this->getDatabaseName(),
            'summary' => [
                'total_issues' => count($this->issues),
                'high_priority' => count(array_filter($this->issues, fn($i) => $i['severity'] === 'high')),
                'medium_priority' => count(array_filter($this->issues, fn($i) => $i['severity'] === 'medium')),
                'low_priority' => count(array_filter($this->issues, fn($i) => $i['severity'] === 'low')),
                'optimizations' => count($this->recommendations),
            ],
            'issues' => $this->issues,
            'optimization_plan' => $this->recommendations,
            'table_stats' => $this->getTableStats()
        ];
        
        file_put_contents($reportFile, json_encode($report, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
        
        echo "📄 報告已生成: $reportFile\n";
        
        // 生成 Markdown 報告
        $this->generateMarkdownReport($reportDir);
        
        // 顯示摘要
        echo "\n📊 分析摘要:\n";
        echo "- 總問題數: " . $report['summary']['total_issues'] . "\n";
        echo "- 高優先級: " . $report['summary']['high_priority'] . "\n";
        echo "- 中優先級: " . $report['summary']['medium_priority'] . "\n";
        echo "- 低優先級: " . $report['summary']['low_priority'] . "\n";
        echo "- 最佳化建議: " . $report['summary']['optimizations'] . "\n";
        
        if ($report['summary']['total_issues'] === 0) {
            echo "✅ 恭喜！資料庫約束和索引配置良好\n";
        } else {
            echo "⚠️  建議檢查並執行最佳化計劃\n";
        }
    }
    
    /**
     * 生成 Markdown 報告
     */
    private function generateMarkdownReport($reportDir) {
        $mdFile = $reportDir . '/constraint_optimization_' . date('Y-m-d_H-i-s') . '.md';
        
        $content = "# 外鍵約束與索引最佳化報告\n\n";
        $content .= "**分析日期**: " . date('Y-m-d H:i:s') . "\n";
        $content .= "**資料庫**: " . $this->getDatabaseName() . "\n\n";
        
        $content .= "## 📊 摘要\n\n";
        $content .= "| 優先級 | 問題數量 |\n";
        $content .= "|--------|----------|\n";
        $content .= "| 高 | " . count(array_filter($this->issues, fn($i) => $i['severity'] === 'high')) . " |\n";
        $content .= "| 中 | " . count(array_filter($this->issues, fn($i) => $i['severity'] === 'medium')) . " |\n";
        $content .= "| 低 | " . count(array_filter($this->issues, fn($i) => $i['severity'] === 'low')) . " |\n";
        $content .= "| **總計** | **" . count($this->issues) . "** |\n\n";
        
        if (!empty($this->issues)) {
            $content .= "## 🚨 發現的問題\n\n";
            
            foreach ($this->issues as $i => $issue) {
                $severityIcon = $issue['severity'] === 'high' ? '🔴' : ($issue['severity'] === 'medium' ? '🟡' : '🟢');
                $content .= "### " . ($i + 1) . ". $severityIcon {$issue['message']}\n\n";
                $content .= "- **類型**: {$issue['type']}\n";
                $content .= "- **嚴重程度**: {$issue['severity']}\n";
                
                if (isset($issue['table'])) {
                    $content .= "- **表格**: {$issue['table']}\n";
                }
                if (isset($issue['column'])) {
                    $content .= "- **欄位**: {$issue['column']}\n";
                }
                
                $content .= "\n";
            }
        }
        
        if (!empty($this->recommendations)) {
            $content .= "## 🔧 最佳化計劃\n\n";
            
            foreach ($this->recommendations as $i => $rec) {
                $riskIcon = $rec['risk'] === 'high' ? '🔴' : ($rec['risk'] === 'medium' ? '🟡' : '🟢');
                $content .= "### " . ($i + 1) . ". $riskIcon {$rec['description']}\n\n";
                $content .= "- **表格**: {$rec['table']}\n";
                $content .= "- **風險等級**: {$rec['risk']}\n";
                $content .= "- **SQL**: \n```sql\n{$rec['sql']}\n```\n\n";
            }
        }
        
        $content .= "## 📋 建議\n\n";
        $content .= "1. **備份資料庫**: 在執行任何最佳化之前，請先完整備份資料庫\n";
        $content .= "2. **測試環境**: 先在測試環境執行最佳化腳本\n";
        $content .= "3. **分階段執行**: 按優先級分階段執行最佳化\n";
        $content .= "4. **監控性能**: 最佳化後監控查詢性能變化\n";
        $content .= "5. **定期檢查**: 建議每季度執行一次約束和索引分析\n\n";
        
        file_put_contents($mdFile, $content);
        echo "📄 Markdown 報告已生成: $mdFile\n";
    }
    
    /**
     * 輔助方法
     */
    private function columnExists($table, $column) {
        $sql = "
            SELECT COUNT(*) 
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_SCHEMA = DATABASE()
            AND TABLE_NAME = ? 
            AND COLUMN_NAME = ?
        ";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute([$table, $column]);
        return $stmt->fetchColumn() > 0;
    }
    
    private function getExistingIndexes() {
        $sql = "
            SELECT CONCAT(TABLE_NAME, '.', COLUMN_NAME) as index_key
            FROM INFORMATION_SCHEMA.STATISTICS 
            WHERE TABLE_SCHEMA = DATABASE()
            AND INDEX_NAME != 'PRIMARY'
        ";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        $indexes = $stmt->fetchAll(PDO::FETCH_COLUMN);
        
        $result = [];
        foreach ($indexes as $index) {
            $result[$index] = true;
        }
        
        return $result;
    }
    
    private function getDatabaseName() {
        $stmt = $this->db->query("SELECT DATABASE() as db_name");
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        return $result['db_name'];
    }
    
    private function getTableStats() {
        $sql = "
            SELECT 
                TABLE_NAME,
                TABLE_ROWS,
                DATA_LENGTH,
                INDEX_LENGTH
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_SCHEMA = DATABASE()
            AND TABLE_TYPE = 'BASE TABLE'
            ORDER BY TABLE_ROWS DESC
        ";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
    
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
        $optimizer = new ConstraintOptimizer();
        $result = $optimizer->runFullAnalysis();
        
        echo "\n🎉 約束與索引分析完成！\n";
        
    } catch (Exception $e) {
        echo "❌ 分析失敗: " . $e->getMessage() . "\n";
        exit(1);
    }
}
