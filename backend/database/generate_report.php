<?php
/**
 * 資料庫結構報告生成器
 * 生成詳細的資料庫結構報告，包含表格、欄位、索引和外鍵關係
 */

require_once __DIR__ . '/../config/database.php';

class DatabaseReportGenerator {
    private $db;
    private $report = [];
    
    public function __construct() {
        $this->db = Database::getInstance();
    }
    
    public function generateReport() {
        echo "=== 資料庫結構報告生成開始 ===\n";
        echo "資料庫: " . $this->getDatabaseName() . "\n\n";
        
        $this->report['database'] = $this->getDatabaseInfo();
        $this->report['tables'] = $this->getTablesInfo();
        $this->report['foreign_keys'] = $this->getForeignKeysInfo();
        $this->report['indexes'] = $this->getIndexesInfo();
        $this->report['data_summary'] = $this->getDataSummary();
        
        $this->saveReport();
        $this->printSummary();
    }
    
    private function getDatabaseName() {
        $result = $this->db->fetch("SELECT DATABASE() as db_name");
        return $result['db_name'];
    }
    
    private function getDatabaseInfo() {
        $info = $this->db->fetch("SELECT DATABASE() as db_name");
        
        // 獲取資料庫大小
        $size = $this->db->fetch("
            SELECT 
                ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS size_mb
            FROM information_schema.tables 
            WHERE table_schema = DATABASE()
        ");
        
        // 獲取表格數量
        $tableCount = $this->db->fetch("
            SELECT COUNT(*) as count 
            FROM information_schema.tables 
            WHERE table_schema = DATABASE()
        ");
        
        return [
            'name' => $info['db_name'],
            'size_mb' => $size['size_mb'] ?? 0,
            'table_count' => $tableCount['count'] ?? 0,
            'generated_at' => date('Y-m-d H:i:s')
        ];
    }
    
    private function getTablesInfo() {
        $tables = $this->db->fetchAll("
            SELECT 
                TABLE_NAME,
                TABLE_ROWS,
                DATA_LENGTH,
                INDEX_LENGTH,
                ENGINE,
                TABLE_COLLATION
            FROM information_schema.tables 
            WHERE table_schema = DATABASE()
            ORDER BY TABLE_NAME
        ");
        
        $tablesInfo = [];
        foreach ($tables as $table) {
            $tableName = $table['TABLE_NAME'];
            $columns = $this->getTableColumns($tableName);
            $tablesInfo[$tableName] = [
                'info' => $table,
                'columns' => $columns
            ];
        }
        
        return $tablesInfo;
    }
    
    private function getTableColumns($tableName) {
        return $this->db->fetchAll("
            SELECT 
                COLUMN_NAME,
                DATA_TYPE,
                IS_NULLABLE,
                COLUMN_DEFAULT,
                EXTRA,
                COLUMN_KEY,
                COLUMN_COMMENT
            FROM information_schema.columns 
            WHERE table_schema = DATABASE() 
            AND table_name = ?
            ORDER BY ORDINAL_POSITION
        ", [$tableName]);
    }
    
    private function getForeignKeysInfo() {
        return $this->db->fetchAll("
            SELECT 
                TABLE_NAME,
                COLUMN_NAME,
                CONSTRAINT_NAME,
                REFERENCED_TABLE_NAME,
                REFERENCED_COLUMN_NAME,
                UPDATE_RULE,
                DELETE_RULE
            FROM information_schema.key_column_usage 
            WHERE table_schema = DATABASE() 
            AND referenced_table_name IS NOT NULL
            ORDER BY table_name, column_name
        ");
    }
    
    private function getIndexesInfo() {
        return $this->db->fetchAll("
            SELECT 
                TABLE_NAME,
                INDEX_NAME,
                COLUMN_NAME,
                NON_UNIQUE,
                SEQ_IN_INDEX,
                CARDINALITY
            FROM information_schema.statistics 
            WHERE table_schema = DATABASE() 
            ORDER BY table_name, index_name, seq_in_index
        ");
    }
    
    private function getDataSummary() {
        $summary = [];
        
        // 獲取每個表格的記錄數
        $tables = $this->db->fetchAll("
            SELECT TABLE_NAME 
            FROM information_schema.tables 
            WHERE table_schema = DATABASE()
        ");
        
        foreach ($tables as $table) {
            $tableName = $table['TABLE_NAME'];
            try {
                $count = $this->db->fetch("SELECT COUNT(*) as count FROM `$tableName`");
                $summary[$tableName] = $count['count'];
            } catch (Exception $e) {
                $summary[$tableName] = 'Error: ' . $e->getMessage();
            }
        }
        
        return $summary;
    }
    
    private function saveReport() {
        $reportDir = __DIR__ . '/reports';
        if (!is_dir($reportDir)) {
            mkdir($reportDir, 0755, true);
        }
        
        $filename = $reportDir . '/database_structure_' . date('Y-m-d_H-i-s') . '.json';
        file_put_contents($filename, json_encode($this->report, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
        
        // 生成 HTML 報告
        $this->generateHtmlReport($reportDir);
        
        echo "報告已保存到: $filename\n";
    }
    
    private function generateHtmlReport($reportDir) {
        $html = $this->generateHtmlContent();
        $filename = $reportDir . '/database_structure_' . date('Y-m-d_H-i-s') . '.html';
        file_put_contents($filename, $html);
        echo "HTML 報告已保存到: $filename\n";
    }
    
    private function generateHtmlContent() {
        $dbInfo = $this->report['database'];
        $tables = $this->report['tables'];
        $foreignKeys = $this->report['foreign_keys'];
        $indexes = $this->report['indexes'];
        $dataSummary = $this->report['data_summary'];
        
        $html = '<!DOCTYPE html>
<html lang="zh-TW">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>資料庫結構報告</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1, h2, h3 { color: #333; }
        .summary { background: #e8f4fd; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .table-section { margin-bottom: 30px; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; font-weight: bold; }
        .table-name { background: #007bff; color: white; padding: 10px; border-radius: 5px; margin-bottom: 10px; }
        .column-info { margin-left: 20px; }
        .fk-section, .index-section { margin-top: 20px; }
        .status { padding: 5px 10px; border-radius: 3px; font-size: 12px; }
        .status.success { background: #d4edda; color: #155724; }
        .status.warning { background: #fff3cd; color: #856404; }
        .status.error { background: #f8d7da; color: #721c24; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 資料庫結構報告</h1>
        
        <div class="summary">
            <h2>📋 資料庫概覽</h2>
            <p><strong>資料庫名稱:</strong> ' . htmlspecialchars($dbInfo['name']) . '</p>
            <p><strong>大小:</strong> ' . $dbInfo['size_mb'] . ' MB</p>
            <p><strong>表格數量:</strong> ' . $dbInfo['table_count'] . '</p>
            <p><strong>生成時間:</strong> ' . $dbInfo['generated_at'] . '</p>
        </div>
        
        <div class="table-section">
            <h2>🗂️ 表格結構</h2>';
        
        foreach ($tables as $tableName => $tableInfo) {
            $html .= '
            <div class="table-name">
                <h3>📋 ' . htmlspecialchars($tableName) . '</h3>
                <p>記錄數: ' . ($dataSummary[$tableName] ?? 'N/A') . ' | 引擎: ' . $tableInfo['info']['ENGINE'] . '</p>
            </div>
            
            <div class="column-info">
                <h4>欄位結構:</h4>
                <table>
                    <tr>
                        <th>欄位名稱</th>
                        <th>資料類型</th>
                        <th>可為空</th>
                        <th>預設值</th>
                        <th>額外</th>
                        <th>鍵</th>
                        <th>註解</th>
                    </tr>';
            
            foreach ($tableInfo['columns'] as $column) {
                $html .= '
                    <tr>
                        <td>' . htmlspecialchars($column['COLUMN_NAME']) . '</td>
                        <td>' . htmlspecialchars($column['DATA_TYPE']) . '</td>
                        <td>' . ($column['IS_NULLABLE'] === 'YES' ? '是' : '否') . '</td>
                        <td>' . htmlspecialchars($column['COLUMN_DEFAULT'] ?? 'NULL') . '</td>
                        <td>' . htmlspecialchars($column['EXTRA']) . '</td>
                        <td>' . htmlspecialchars($column['COLUMN_KEY']) . '</td>
                        <td>' . htmlspecialchars($column['COLUMN_COMMENT']) . '</td>
                    </tr>';
            }
            
            $html .= '
                </table>
            </div>';
        }
        
        $html .= '
        </div>
        
        <div class="fk-section">
            <h2>🔗 外鍵關係</h2>
            <table>
                <tr>
                    <th>表格</th>
                    <th>欄位</th>
                    <th>約束名稱</th>
                    <th>參考表格</th>
                    <th>參考欄位</th>
                    <th>更新規則</th>
                    <th>刪除規則</th>
                </tr>';
        
        foreach ($foreignKeys as $fk) {
            $html .= '
                <tr>
                    <td>' . htmlspecialchars($fk['TABLE_NAME']) . '</td>
                    <td>' . htmlspecialchars($fk['COLUMN_NAME']) . '</td>
                    <td>' . htmlspecialchars($fk['CONSTRAINT_NAME']) . '</td>
                    <td>' . htmlspecialchars($fk['REFERENCED_TABLE_NAME']) . '</td>
                    <td>' . htmlspecialchars($fk['REFERENCED_COLUMN_NAME']) . '</td>
                    <td>' . htmlspecialchars($fk['UPDATE_RULE']) . '</td>
                    <td>' . htmlspecialchars($fk['DELETE_RULE']) . '</td>
                </tr>';
        }
        
        $html .= '
            </table>
        </div>
        
        <div class="index-section">
            <h2>📈 索引資訊</h2>
            <table>
                <tr>
                    <th>表格</th>
                    <th>索引名稱</th>
                    <th>欄位</th>
                    <th>順序</th>
                    <th>唯一性</th>
                    <th>基數</th>
                </tr>';
        
        foreach ($indexes as $index) {
            $html .= '
                <tr>
                    <td>' . htmlspecialchars($index['TABLE_NAME']) . '</td>
                    <td>' . htmlspecialchars($index['INDEX_NAME']) . '</td>
                    <td>' . htmlspecialchars($index['COLUMN_NAME']) . '</td>
                    <td>' . $index['SEQ_IN_INDEX'] . '</td>
                    <td>' . ($index['NON_UNIQUE'] ? '否' : '是') . '</td>
                    <td>' . $index['CARDINALITY'] . '</td>
                </tr>';
        }
        
        $html .= '
            </table>
        </div>
        
        <div class="data-summary">
            <h2>📊 資料統計</h2>
            <table>
                <tr>
                    <th>表格名稱</th>
                    <th>記錄數</th>
                </tr>';
        
        foreach ($dataSummary as $tableName => $count) {
            $html .= '
                <tr>
                    <td>' . htmlspecialchars($tableName) . '</td>
                    <td>' . $count . '</td>
                </tr>';
        }
        
        $html .= '
            </table>
        </div>
    </div>
</body>
</html>';
        
        return $html;
    }
    
    private function printSummary() {
        echo "\n=== 報告生成完成 ===\n";
        echo "✅ 資料庫: " . $this->report['database']['name'] . "\n";
        echo "✅ 表格數量: " . $this->report['database']['table_count'] . "\n";
        echo "✅ 資料庫大小: " . $this->report['database']['size_mb'] . " MB\n";
        echo "✅ 外鍵關係: " . count($this->report['foreign_keys']) . " 個\n";
        echo "✅ 索引數量: " . count($this->report['indexes']) . " 個\n";
        echo "\n報告已保存到 backend/database/reports/ 目錄\n";
    }
}

// 執行報告生成
try {
    $generator = new DatabaseReportGenerator();
    $generator->generateReport();
} catch (Exception $e) {
    echo "報告生成過程中發生錯誤: " . $e->getMessage() . "\n";
}
?> 