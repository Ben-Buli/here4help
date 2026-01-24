<?php
/**
 * 初始化提領手續費設定腳本
 * 如果 withdraw_fee_settings 表不存在或沒有啟用的設定，則創建預設設定
 */

require_once __DIR__ . '/../config/database.php';

try {
    $db = Database::getInstance();
    
    // 檢查表是否存在
    $tableExists = $db->fetch("SHOW TABLES LIKE 'withdraw_fee_settings'");
    
    if (!$tableExists) {
        echo "Creating withdraw_fee_settings table...\n";
        
        // 創建表
        $createTableSQL = "
            CREATE TABLE withdraw_fee_settings (
                id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
                rate DECIMAL(6,4) NOT NULL COMMENT '提領手續費率，0.02 表示 2%',
                description VARCHAR(255) DEFAULT NULL COMMENT '設定描述',
                is_active TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否啟用',
                updated_by BIGINT UNSIGNED NULL COMMENT '更新者ID',
                min_withdraw_points INT UNSIGNED DEFAULT NULL COMMENT '最低提領門檻（點數）',
                created_at TIMESTAMP NULL DEFAULT NULL,
                updated_at TIMESTAMP NULL DEFAULT NULL,
                INDEX idx_active (is_active),
                INDEX idx_updated_at (updated_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ";
        
        $db->execute($createTableSQL);
        echo "Table created successfully.\n";
    }
    
    // 檢查是否有啟用的設定
    $activeSettings = $db->fetch("SELECT id FROM withdraw_fee_settings WHERE is_active = 1 LIMIT 1");
    
    if (!$activeSettings) {
        echo "Creating default fee settings...\n";
        
        // 插入預設設定（2% 手續費）
        $insertSQL = "
            INSERT INTO withdraw_fee_settings (
                rate, description, is_active, updated_by, created_at, updated_at
            ) VALUES (0.0200, 'Default 2% withdraw fee', 1, NULL, NOW(), NOW())
        ";
        
        $db->execute($insertSQL);
        $settingsId = $db->lastInsertId();
        
        echo "Default fee settings created with ID: $settingsId\n";
        echo "Rate: 2.00%\n";
        echo "Description: Default 2% completion fee\n";
    } else {
        echo "Active fee settings already exist.\n";
    }
    
    // 顯示當前設定
    $currentSettings = $db->fetch("
        SELECT id, rate, description, is_active, created_at 
        FROM withdraw_fee_settings 
        WHERE is_active = 1 
        ORDER BY id DESC 
        LIMIT 1
    ");
    
    if ($currentSettings) {
        echo "\nCurrent active settings:\n";
        echo "ID: " . $currentSettings['id'] . "\n";
        echo "Rate: " . number_format((float)$currentSettings['rate'] * 100, 2) . "%\n";
        echo "Description: " . $currentSettings['description'] . "\n";
        echo "Active: " . ($currentSettings['is_active'] ? 'Yes' : 'No') . "\n";
        echo "Created: " . $currentSettings['created_at'] . "\n";
    }
    
    echo "\nFee settings initialization completed successfully.\n";
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    exit(1);
}
?>
