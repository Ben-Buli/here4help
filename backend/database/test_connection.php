<?php
/**
 * 資料庫連線測試腳本
 * 用於驗證資料庫配置是否正確
 */

require_once __DIR__ . '/../config/database.php';

echo "=== 資料庫連線測試 ===\n";

try {
    $db = Database::getInstance();
    echo "✅ 資料庫連線成功！\n";
    
    // 獲取資料庫資訊
    $dbName = $db->fetch("SELECT DATABASE() as db_name");
    echo "📊 資料庫名稱: " . $dbName['db_name'] . "\n";
    
    // 獲取表格列表
    $tables = $db->fetchAll("
        SELECT TABLE_NAME 
        FROM information_schema.tables 
        WHERE table_schema = DATABASE()
        ORDER BY TABLE_NAME
    ");
    
    echo "📋 表格數量: " . count($tables) . "\n";
    
    if (!empty($tables)) {
        echo "📋 表格列表:\n";
        foreach ($tables as $table) {
            echo "  - " . $table['TABLE_NAME'] . "\n";
        }
    }
    
    // 測試查詢
    echo "\n🔍 測試查詢...\n";
    $result = $db->fetch("SELECT 1 as test");
    if ($result['test'] == 1) {
        echo "✅ 查詢測試通過！\n";
    }
    
    echo "\n🎉 所有測試通過！資料庫配置正確。\n";
    
} catch (Exception $e) {
    echo "❌ 資料庫連線失敗: " . $e->getMessage() . "\n";
    echo "\n🔧 請檢查以下項目：\n";
    echo "1. 資料庫服務是否啟動\n";
    echo "2. 資料庫配置是否正確\n";
    echo "3. 用戶權限是否足夠\n";
    echo "4. 網路連線是否正常\n";
    exit(1);
}
?> 