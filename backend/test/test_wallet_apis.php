<?php
/**
 * 測試錢包相關 API
 * 使用方法: 在瀏覽器中訪問此文件，或使用 curl 命令
 */

require_once dirname(__DIR__, 1) . '/config/database.php';
require_once dirname(__DIR__, 1) . '/utils/response.php';
require_once dirname(__DIR__, 1) . '/utils/JWTManager.php';

header('Content-Type: application/json');

echo "=== 錢包 API 測試 ===\n\n";

try {
    $db = Database::getInstance();
    
    // 1. 測試數據庫連接
    echo "1. 測試數據庫連接...\n";
    $testQuery = "SELECT 1 as test";
    $result = $db->fetch($testQuery);
    if ($result) {
        echo "✅ 數據庫連接正常\n\n";
    } else {
        echo "❌ 數據庫連接失敗\n\n";
        exit;
    }
    
    // 2. 檢查 official_bank_accounts 表
    echo "2. 檢查 official_bank_accounts 表...\n";
    $tableExists = $db->fetch("SHOW TABLES LIKE 'official_bank_accounts'");
    if ($tableExists) {
        echo "✅ official_bank_accounts 表存在\n";
        
        // 檢查是否有啟用的帳戶
        $activeAccount = $db->fetch("SELECT * FROM official_bank_accounts WHERE is_active = 1 LIMIT 1");
        if ($activeAccount) {
            echo "✅ 找到啟用的銀行帳戶\n";
        } else {
            echo "⚠️ 沒有啟用的銀行帳戶，創建預設帳戶...\n";
            $db->execute("INSERT INTO official_bank_accounts (bank_name, account_number, account_holder, is_active, admin_id) VALUES (?, ?, ?, ?, ?)", [
                '台灣銀行',
                '1234567890123456',
                'Here4Help Platform',
                1,
                1
            ]);
            echo "✅ 已創建預設銀行帳戶\n";
        }
    } else {
        echo "❌ official_bank_accounts 表不存在，創建表...\n";
        $createTableSql = "
        CREATE TABLE IF NOT EXISTS `official_bank_accounts` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `bank_name` varchar(100) NOT NULL COMMENT '銀行名稱',
          `account_number` varchar(20) NOT NULL COMMENT '帳號',
          `account_holder` varchar(100) NOT NULL COMMENT '帳戶持有人',
          `is_active` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否啟用',
          `admin_id` int(11) DEFAULT NULL COMMENT '創建者管理員ID',
          `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_is_active` (`is_active`),
          KEY `idx_admin_id` (`admin_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='官方銀行帳戶資訊'
        ";
        $db->execute($createTableSql);
        
        // 插入預設數據
        $db->execute("INSERT INTO official_bank_accounts (bank_name, account_number, account_holder, is_active, admin_id) VALUES (?, ?, ?, ?, ?)", [
            '台灣銀行',
            '1234567890123456',
            'Here4Help Platform',
            1,
            1
        ]);
        echo "✅ 已創建 official_bank_accounts 表和預設數據\n";
    }
    echo "\n";
    
    // 3. 檢查 task_completion_points_fee_settings 表
    echo "3. 檢查 task_completion_points_fee_settings 表...\n";
    $tableExists = $db->fetch("SHOW TABLES LIKE 'task_completion_points_fee_settings'");
    if ($tableExists) {
        echo "✅ task_completion_points_fee_settings 表存在\n";
        
        // 檢查是否有啟用的設定
        $activeSettings = $db->fetch("SELECT * FROM task_completion_points_fee_settings WHERE is_active = 1 LIMIT 1");
        if ($activeSettings) {
            echo "✅ 找到啟用的手續費設定\n";
        } else {
            echo "⚠️ 沒有啟用的手續費設定，創建預設設定...\n";
            $db->execute("INSERT INTO task_completion_points_fee_settings (rate, is_active, description) VALUES (?, ?, ?)", [
                0.0500,
                1,
                '任務完成手續費 5%'
            ]);
            echo "✅ 已創建預設手續費設定\n";
        }
    } else {
        echo "❌ task_completion_points_fee_settings 表不存在，創建表...\n";
        $createTableSql = "
        CREATE TABLE IF NOT EXISTS `task_completion_points_fee_settings` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `rate` decimal(5,4) NOT NULL DEFAULT '0.0000' COMMENT '手續費率 (0.0000 = 0%, 0.0500 = 5%)',
          `is_active` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否啟用',
          `description` text COMMENT '設定說明',
          `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_is_active` (`is_active`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='任務完成手續費設定'
        ";
        $db->execute($createTableSql);
        
        // 插入預設數據
        $db->execute("INSERT INTO task_completion_points_fee_settings (rate, is_active, description) VALUES (?, ?, ?)", [
            0.0500,
            1,
            '任務完成手續費 5%'
        ]);
        echo "✅ 已創建 task_completion_points_fee_settings 表和預設數據\n";
    }
    echo "\n";
    
    // 4. 檢查 users 表是否有測試用戶
    echo "4. 檢查測試用戶...\n";
    $testUser = $db->fetch("SELECT id, name, points FROM users WHERE email = 'chris@test.com' LIMIT 1");
    if ($testUser) {
        echo "✅ 找到測試用戶: {$testUser['name']} (ID: {$testUser['id']}, 點數: {$testUser['points']})\n";
    } else {
        echo "⚠️ 沒有找到測試用戶 chris@test.com\n";
    }
    echo "\n";
    
    // 5. 測試 API 端點
    echo "5. 測試 API 端點...\n";
    echo "請手動測試以下端點:\n";
    echo "- GET /backend/api/wallet/summary.php?token=<your_token>\n";
    echo "- GET /backend/api/wallet/bank-accounts.php?token=<your_token>\n";
    echo "- GET /backend/api/wallet/fee-settings.php?token=<your_token>\n";
    echo "\n";
    
    echo "=== 測試完成 ===\n";
    echo "如果所有檢查都通過，錢包功能應該可以正常工作。\n";
    
} catch (Exception $e) {
    echo "❌ 測試失敗: " . $e->getMessage() . "\n";
}
?>
