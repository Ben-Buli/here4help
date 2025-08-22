<?php
/**
 * 快速資料庫驗證腳本
 * 直接執行驗證，適合自動化腳本使用
 */

require_once __DIR__ . '/../config/database.php';

echo "=== 快速資料庫驗證 ===\n";
echo "時間: " . date('Y-m-d H:i:s') . "\n\n";

try {
    $db = Database::getInstance();
    echo "✅ 資料庫連線成功\n";
    
    // 獲取資料庫資訊
    $dbName = $db->fetch("SELECT DATABASE() as db_name");
    echo "📊 資料庫: " . $dbName['db_name'] . "\n";
    
    // 檢查核心表格
    $coreTables = ['users', 'tasks', 'task_statuses', 'chat_rooms', 'chat_messages', 'chat_reads'];
    $missingTables = [];
    $existingTables = [];
    
    foreach ($coreTables as $table) {
        $exists = $db->fetch("
            SELECT COUNT(*) as count 
            FROM information_schema.tables 
            WHERE table_schema = DATABASE() 
            AND table_name = ?
        ", [$table]);
        
        if ($exists['count'] > 0) {
            $existingTables[] = $table;
            echo "✅ $table 表格存在\n";
        } else {
            $missingTables[] = $table;
            echo "❌ $table 表格不存在\n";
        }
    }
    
    // 檢查外鍵關係
    echo "\n🔗 檢查外鍵關係...\n";
    $foreignKeys = $db->fetchAll("
        SELECT 
            TABLE_NAME,
            COLUMN_NAME,
            REFERENCED_TABLE_NAME,
            REFERENCED_COLUMN_NAME
        FROM information_schema.key_column_usage 
        WHERE table_schema = DATABASE() 
        AND referenced_table_name IS NOT NULL
        ORDER BY table_name, column_name
    ");
    
    if (!empty($foreignKeys)) {
        echo "✅ 發現 " . count($foreignKeys) . " 個外鍵關係\n";
        foreach ($foreignKeys as $fk) {
            echo "  - {$fk['TABLE_NAME']}.{$fk['COLUMN_NAME']} -> {$fk['REFERENCED_TABLE_NAME']}.{$fk['REFERENCED_COLUMN_NAME']}\n";
        }
    } else {
        echo "⚠️  沒有發現外鍵關係\n";
    }
    
    // 檢查索引
    echo "\n📈 檢查索引...\n";
    $indexes = $db->fetchAll("
        SELECT 
            TABLE_NAME,
            INDEX_NAME,
            COLUMN_NAME,
            NON_UNIQUE
        FROM information_schema.statistics 
        WHERE table_schema = DATABASE() 
        AND index_name != 'PRIMARY'
        ORDER BY table_name, index_name
    ");
    
    if (!empty($indexes)) {
        echo "✅ 發現 " . count($indexes) . " 個非主鍵索引\n";
        foreach ($indexes as $index) {
            $type = $index['NON_UNIQUE'] ? 'INDEX' : 'UNIQUE';
            echo "  - {$index['TABLE_NAME']}.{$index['INDEX_NAME']} ({$index['COLUMN_NAME']}) - $type\n";
        }
    } else {
        echo "⚠️  沒有發現非主鍵索引\n";
    }
    
    // 檢查資料統計
    echo "\n📊 資料統計...\n";
    foreach ($existingTables as $table) {
        try {
            $count = $db->fetch("SELECT COUNT(*) as count FROM `$table`");
            echo "  - $table: {$count['count']} 筆記錄\n";
        } catch (Exception $e) {
            echo "  - $table: 查詢失敗 - " . $e->getMessage() . "\n";
        }
    }
    
    // 總結
    echo "\n=== 驗證總結 ===\n";
    echo "✅ 連線狀態: 正常\n";
    echo "✅ 核心表格: " . count($existingTables) . "/" . count($coreTables) . " 存在\n";
    echo "✅ 外鍵關係: " . count($foreignKeys) . " 個\n";
    echo "✅ 索引數量: " . count($indexes) . " 個\n";
    
    if (!empty($missingTables)) {
        echo "\n⚠️  缺少表格: " . implode(', ', $missingTables) . "\n";
        echo "💡 建議執行修復腳本: php fix_structure.php\n";
    }
    
    if (empty($foreignKeys)) {
        echo "\n⚠️  沒有外鍵關係，建議檢查資料完整性\n";
    }
    
    if (empty($indexes)) {
        echo "\n⚠️  沒有非主鍵索引，建議添加索引提升效能\n";
    }
    
    echo "\n🎉 快速驗證完成！\n";
    
} catch (Exception $e) {
    echo "❌ 驗證失敗: " . $e->getMessage() . "\n";
    exit(1);
}
?> 