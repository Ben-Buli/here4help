<?php
/**
 * ID/FK 類型差異審計工具
 * 檢查所有表格的 ID 和外鍵類型一致性
 */

require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../config/database.php';

class IdAudit {
    private $db;
    private $issues = [];
    private $recommendations = [];
    
    public function __construct() {
        $this->db = Database::getInstance()->getConnection();
    }
    
    /**
     * 執行完整的 ID/FK 審計
     */
    public function runFullAudit() {
        echo "🔍 開始 ID/FK 類型差異審計\n";
        echo "==========================\n\n";
        
        $this->checkPrimaryKeyTypes();
        $this->checkForeignKeyConsistency();
        $this->checkIndexTypes();
        $this->generateMigrationPlan();
        $this->generateReport();
        
        return [
            'issues' => $this->issues,
            'recommendations' => $this->recommendations
        ];
    }
    
    /**
     * 檢查主鍵類型
     */
    private function checkPrimaryKeyTypes() {
        echo "1. 檢查主鍵類型一致性\n";
        echo "---------------------\n";
        
        $sql = "
            SELECT 
                TABLE_NAME,
                COLUMN_NAME,
                DATA_TYPE,
                IS_NULLABLE,
                COLUMN_KEY,
                EXTRA
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_SCHEMA = DATABASE()
            AND COLUMN_KEY = 'PRI'
            ORDER BY TABLE_NAME
        ";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        $primaryKeys = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        $pkTypes = [];
        foreach ($primaryKeys as $pk) {
            $pkTypes[$pk['TABLE_NAME']] = [
                'column' => $pk['COLUMN_NAME'],
                'type' => $pk['DATA_TYPE'],
                'extra' => $pk['EXTRA']
            ];
            
            echo "- {$pk['TABLE_NAME']}.{$pk['COLUMN_NAME']}: {$pk['DATA_TYPE']} {$pk['EXTRA']}\n";
        }
        
        // 檢查類型不一致
        $typeGroups = [];
        foreach ($pkTypes as $table => $info) {
            $typeKey = $info['type'] . '_' . $info['extra'];
            $typeGroups[$typeKey][] = $table;
        }
        
        echo "\n主鍵類型分組:\n";
        foreach ($typeGroups as $type => $tables) {
            echo "- $type: " . implode(', ', $tables) . "\n";
            
            if (count($tables) > 1 && strpos($type, 'bigint') === false) {
                $this->issues[] = [
                    'type' => 'primary_key_inconsistency',
                    'severity' => 'medium',
                    'tables' => $tables,
                    'current_type' => $type,
                    'message' => "多個表格使用不同的主鍵類型，建議統一使用 BIGINT UNSIGNED AUTO_INCREMENT"
                ];
            }
        }
        
        echo "\n";
    }
    
    /**
     * 檢查外鍵一致性
     */
    private function checkForeignKeyConsistency() {
        echo "2. 檢查外鍵類型一致性\n";
        echo "---------------------\n";
        
        // 獲取所有外鍵關係
        $sql = "
            SELECT 
                kcu.TABLE_NAME,
                kcu.COLUMN_NAME,
                kcu.REFERENCED_TABLE_NAME,
                kcu.REFERENCED_COLUMN_NAME,
                c1.DATA_TYPE as FK_TYPE,
                c2.DATA_TYPE as REF_TYPE,
                c1.IS_NULLABLE as FK_NULLABLE,
                c2.IS_NULLABLE as REF_NULLABLE
            FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
            JOIN INFORMATION_SCHEMA.COLUMNS c1 
                ON kcu.TABLE_NAME = c1.TABLE_NAME 
                AND kcu.COLUMN_NAME = c1.COLUMN_NAME
                AND kcu.TABLE_SCHEMA = c1.TABLE_SCHEMA
            JOIN INFORMATION_SCHEMA.COLUMNS c2 
                ON kcu.REFERENCED_TABLE_NAME = c2.TABLE_NAME 
                AND kcu.REFERENCED_COLUMN_NAME = c2.COLUMN_NAME
                AND kcu.TABLE_SCHEMA = c2.TABLE_SCHEMA
            WHERE kcu.TABLE_SCHEMA = DATABASE()
            AND kcu.REFERENCED_TABLE_NAME IS NOT NULL
            ORDER BY kcu.TABLE_NAME, kcu.COLUMN_NAME
        ";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        $foreignKeys = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        foreach ($foreignKeys as $fk) {
            $status = ($fk['FK_TYPE'] === $fk['REF_TYPE']) ? '✅' : '❌';
            echo "$status {$fk['TABLE_NAME']}.{$fk['COLUMN_NAME']} ({$fk['FK_TYPE']}) -> {$fk['REFERENCED_TABLE_NAME']}.{$fk['REFERENCED_COLUMN_NAME']} ({$fk['REF_TYPE']})\n";
            
            if ($fk['FK_TYPE'] !== $fk['REF_TYPE']) {
                $this->issues[] = [
                    'type' => 'foreign_key_type_mismatch',
                    'severity' => 'high',
                    'table' => $fk['TABLE_NAME'],
                    'column' => $fk['COLUMN_NAME'],
                    'fk_type' => $fk['FK_TYPE'],
                    'referenced_table' => $fk['REFERENCED_TABLE_NAME'],
                    'referenced_column' => $fk['REFERENCED_COLUMN_NAME'],
                    'ref_type' => $fk['REF_TYPE'],
                    'message' => "外鍵類型不匹配：{$fk['FK_TYPE']} vs {$fk['REF_TYPE']}"
                ];
            }
        }
        
        echo "\n";
    }
    
    /**
     * 檢查常見的 ID 欄位類型
     */
    private function checkIndexTypes() {
        echo "3. 檢查常見 ID 欄位類型\n";
        echo "----------------------\n";
        
        $sql = "
            SELECT 
                TABLE_NAME,
                COLUMN_NAME,
                DATA_TYPE,
                IS_NULLABLE,
                COLUMN_DEFAULT,
                EXTRA
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_SCHEMA = DATABASE()
            AND (COLUMN_NAME LIKE '%_id' OR COLUMN_NAME = 'id')
            ORDER BY TABLE_NAME, COLUMN_NAME
        ";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        $idColumns = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        $typeStats = [];
        foreach ($idColumns as $col) {
            $typeKey = $col['DATA_TYPE'];
            $typeStats[$typeKey][] = "{$col['TABLE_NAME']}.{$col['COLUMN_NAME']}";
            
            echo "- {$col['TABLE_NAME']}.{$col['COLUMN_NAME']}: {$col['DATA_TYPE']} {$col['EXTRA']}\n";
            
            // 檢查潛在問題
            if ($col['COLUMN_NAME'] === 'id' && $col['DATA_TYPE'] !== 'bigint') {
                $this->issues[] = [
                    'type' => 'primary_key_not_bigint',
                    'severity' => 'medium',
                    'table' => $col['TABLE_NAME'],
                    'column' => $col['COLUMN_NAME'],
                    'current_type' => $col['DATA_TYPE'],
                    'message' => "主鍵 ID 不是 BIGINT 類型，可能在大量數據時溢出"
                ];
            }
            
            if (strpos($col['COLUMN_NAME'], '_id') !== false && $col['DATA_TYPE'] === 'varchar') {
                $this->issues[] = [
                    'type' => 'varchar_foreign_key',
                    'severity' => 'low',
                    'table' => $col['TABLE_NAME'],
                    'column' => $col['COLUMN_NAME'],
                    'current_type' => $col['DATA_TYPE'],
                    'message' => "外鍵使用 VARCHAR 類型，建議檢查是否應為數值類型"
                ];
            }
        }
        
        echo "\nID 欄位類型統計:\n";
        foreach ($typeStats as $type => $columns) {
            echo "- $type (" . count($columns) . "): " . implode(', ', array_slice($columns, 0, 5));
            if (count($columns) > 5) {
                echo " ... (+" . (count($columns) - 5) . " more)";
            }
            echo "\n";
        }
        
        echo "\n";
    }
    
    /**
     * 生成遷移計劃
     */
    private function generateMigrationPlan() {
        echo "4. 生成遷移計劃\n";
        echo "---------------\n";
        
        $migrationSteps = [];
        
        foreach ($this->issues as $issue) {
            switch ($issue['type']) {
                case 'foreign_key_type_mismatch':
                    $migrationSteps[] = [
                        'priority' => 1,
                        'action' => 'ALTER_COLUMN',
                        'table' => $issue['table'],
                        'column' => $issue['column'],
                        'from_type' => $issue['fk_type'],
                        'to_type' => $issue['ref_type'],
                        'sql' => "ALTER TABLE `{$issue['table']}` MODIFY COLUMN `{$issue['column']}` {$issue['ref_type']} UNSIGNED;",
                        'risk' => 'medium',
                        'description' => "修正外鍵類型不匹配"
                    ];
                    break;
                    
                case 'primary_key_not_bigint':
                    $migrationSteps[] = [
                        'priority' => 2,
                        'action' => 'ALTER_PRIMARY_KEY',
                        'table' => $issue['table'],
                        'column' => $issue['column'],
                        'from_type' => $issue['current_type'],
                        'to_type' => 'BIGINT UNSIGNED',
                        'sql' => "ALTER TABLE `{$issue['table']}` MODIFY COLUMN `{$issue['column']}` BIGINT UNSIGNED AUTO_INCREMENT;",
                        'risk' => 'high',
                        'description' => "升級主鍵為 BIGINT"
                    ];
                    break;
            }
        }
        
        // 按優先級排序
        usort($migrationSteps, function($a, $b) {
            return $a['priority'] - $b['priority'];
        });
        
        $this->recommendations = $migrationSteps;
        
        if (empty($migrationSteps)) {
            echo "✅ 沒有發現需要遷移的問題\n\n";
            return;
        }
        
        echo "建議的遷移步驟:\n";
        foreach ($migrationSteps as $i => $step) {
            $riskColor = $step['risk'] === 'high' ? '🔴' : ($step['risk'] === 'medium' ? '🟡' : '🟢');
            echo ($i + 1) . ". $riskColor {$step['description']}\n";
            echo "   表格: {$step['table']}\n";
            echo "   SQL: {$step['sql']}\n";
            echo "   風險: {$step['risk']}\n\n";
        }
    }
    
    /**
     * 生成詳細報告
     */
    private function generateReport() {
        echo "5. 生成審計報告\n";
        echo "---------------\n";
        
        $reportDir = __DIR__ . '/reports';
        if (!is_dir($reportDir)) {
            mkdir($reportDir, 0755, true);
        }
        
        $reportFile = $reportDir . '/id_audit_' . date('Y-m-d_H-i-s') . '.json';
        
        $report = [
            'audit_date' => date('Y-m-d H:i:s'),
            'database' => $this->getDatabaseName(),
            'summary' => [
                'total_issues' => count($this->issues),
                'high_priority' => count(array_filter($this->issues, fn($i) => $i['severity'] === 'high')),
                'medium_priority' => count(array_filter($this->issues, fn($i) => $i['severity'] === 'medium')),
                'low_priority' => count(array_filter($this->issues, fn($i) => $i['severity'] === 'low')),
            ],
            'issues' => $this->issues,
            'migration_plan' => $this->recommendations,
            'table_analysis' => $this->getTableAnalysis()
        ];
        
        file_put_contents($reportFile, json_encode($report, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
        
        echo "📄 報告已生成: $reportFile\n";
        
        // 生成 Markdown 報告
        $this->generateMarkdownReport($reportDir);
        
        // 顯示摘要
        echo "\n📊 審計摘要:\n";
        echo "- 總問題數: " . $report['summary']['total_issues'] . "\n";
        echo "- 高優先級: " . $report['summary']['high_priority'] . "\n";
        echo "- 中優先級: " . $report['summary']['medium_priority'] . "\n";
        echo "- 低優先級: " . $report['summary']['low_priority'] . "\n";
        
        if ($report['summary']['total_issues'] === 0) {
            echo "✅ 恭喜！沒有發現 ID/FK 類型問題\n";
        } else {
            echo "⚠️  建議檢查並執行遷移計劃\n";
        }
    }
    
    /**
     * 生成 Markdown 報告
     */
    private function generateMarkdownReport($reportDir) {
        $mdFile = $reportDir . '/id_audit_' . date('Y-m-d_H-i-s') . '.md';
        
        $content = "# ID/FK 類型審計報告\n\n";
        $content .= "**審計日期**: " . date('Y-m-d H:i:s') . "\n";
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
            $content .= "## 🔧 遷移計劃\n\n";
            
            foreach ($this->recommendations as $i => $rec) {
                $riskIcon = $rec['risk'] === 'high' ? '🔴' : ($rec['risk'] === 'medium' ? '🟡' : '🟢');
                $content .= "### " . ($i + 1) . ". $riskIcon {$rec['description']}\n\n";
                $content .= "- **表格**: {$rec['table']}\n";
                $content .= "- **風險等級**: {$rec['risk']}\n";
                $content .= "- **SQL**: \n```sql\n{$rec['sql']}\n```\n\n";
            }
        }
        
        $content .= "## 📋 建議\n\n";
        $content .= "1. **備份資料庫**: 在執行任何遷移之前，請先完整備份資料庫\n";
        $content .= "2. **測試環境**: 先在測試環境執行遷移腳本\n";
        $content .= "3. **分階段執行**: 按優先級分階段執行遷移\n";
        $content .= "4. **監控性能**: 遷移後監控查詢性能變化\n";
        $content .= "5. **更新應用程式**: 確保應用程式代碼與新的資料類型相容\n\n";
        
        file_put_contents($mdFile, $content);
        echo "📄 Markdown 報告已生成: $mdFile\n";
    }
    
    /**
     * 獲取資料庫名稱
     */
    private function getDatabaseName() {
        $stmt = $this->db->query("SELECT DATABASE() as db_name");
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        return $result['db_name'];
    }
    
    /**
     * 獲取表格分析
     */
    private function getTableAnalysis() {
        $sql = "
            SELECT 
                TABLE_NAME,
                TABLE_ROWS,
                DATA_LENGTH,
                INDEX_LENGTH,
                AUTO_INCREMENT
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_SCHEMA = DATABASE()
            AND TABLE_TYPE = 'BASE TABLE'
            ORDER BY TABLE_ROWS DESC
        ";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}

// 如果直接執行此腳本
if (basename(__FILE__) === basename($_SERVER['SCRIPT_NAME'])) {
    try {
        $audit = new IdAudit();
        $result = $audit->runFullAudit();
        
        echo "\n🎉 ID/FK 審計完成！\n";
        
    } catch (Exception $e) {
        echo "❌ 審計失敗: " . $e->getMessage() . "\n";
        exit(1);
    }
}

