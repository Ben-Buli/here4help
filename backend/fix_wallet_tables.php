<?php
/**
 * 修復錢包 API 所需的資料庫表格和設定
 * 針對 iOS Flutter 環境的 500 錯誤進行修復
 */

// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/config/php84_compatibility.php';
require_once __DIR__ . '/config/database.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

echo "🔧 錢包 API 表格修復工具\n\n";

try {
    $db = Database::getInstance();
    
    // 1. 檢查並創建 official_bank_accounts 表
    echo "1. 檢查 official_bank_accounts 表...\n";
    $tableExists = $db->fetch("SHOW TABLES LIKE 'official_bank_accounts'");
    
    if (!$tableExists) {
        echo "❌ 表格不存在，正在創建...\n";
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
        echo "✅ official_bank_accounts 表已創建\n";
    } else {
        echo "✅ official_bank_accounts 表已存在\n";
    }
    
    // 檢查並創建預設銀行帳戶
    $activeAccount = $db->fetch("SELECT * FROM official_bank_accounts WHERE is_active = 1 LIMIT 1");
    if (!$activeAccount) {
        echo "❌ 沒有啟用的銀行帳戶，創建預設帳戶...\n";
        $db->execute("INSERT INTO official_bank_accounts (bank_name, account_number, account_holder, is_active, admin_id) VALUES (?, ?, ?, ?, ?)", [
            '台灣銀行',
            '1234567890123456',
            'Here4Help Platform',
            1,
            1
        ]);
        echo "✅ 已創建預設銀行帳戶\n";
    } else {
        echo "✅ 銀行帳戶已配置\n";
    }
    
    echo "\n";
    
    // 2. 檢查並創建 task_completion_points_fee_settings 表
    echo "2. 檢查 task_completion_points_fee_settings 表...\n";
    $tableExists = $db->fetch("SHOW TABLES LIKE 'task_completion_points_fee_settings'");
    
    if (!$tableExists) {
        echo "❌ 表格不存在，正在創建...\n";
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
        echo "✅ task_completion_points_fee_settings 表已創建\n";
    } else {
        echo "✅ task_completion_points_fee_settings 表已存在\n";
    }
    
    // 檢查並創建預設手續費設定
    $activeSettings = $db->fetch("SELECT * FROM task_completion_points_fee_settings WHERE is_active = 1 LIMIT 1");
    if (!$activeSettings) {
        echo "❌ 沒有啟用的手續費設定，創建預設設定...\n";
        $db->execute("INSERT INTO task_completion_points_fee_settings (rate, is_active, description) VALUES (?, ?, ?)", [
            0.0200, // 2% 手續費
            1,
            'Default 2% completion fee'
        ]);
        echo "✅ 已創建預設手續費設定\n";
    } else {
        echo "✅ 手續費設定已配置\n";
    }
    
    echo "\n";
    
    // 3. 測試錢包 API endpoints
    echo "3. 測試錢包 API 端點...\n";
    
    // 測試 summary.php
    $testUrl = "http://" . $_SERVER['HTTP_HOST'] . dirname($_SERVER['PHP_SELF']) . "/api/wallet/summary.php";
    echo "Summary API: $testUrl\n";
    
    // 測試 fee-settings.php
    $testUrl = "http://" . $_SERVER['HTTP_HOST'] . dirname($_SERVER['PHP_SELF']) . "/api/wallet/fee-settings.php";
    echo "Fee Settings API: $testUrl\n";
    
    // 測試 bank-accounts.php
    $testUrl = "http://" . $_SERVER['HTTP_HOST'] . dirname($_SERVER['PHP_SELF']) . "/api/wallet/bank-accounts.php";
    echo "Bank Accounts API: $testUrl\n";
    
    echo "\n";
    
    // 4. 輸出當前設定摘要
    echo "4. 當前設定摘要:\n";
    
    $currentBankAccount = $db->fetch("SELECT * FROM official_bank_accounts WHERE is_active = 1 LIMIT 1");
    if ($currentBankAccount) {
        echo "✅ 銀行帳戶: " . $currentBankAccount['bank_name'] . " (" . $currentBankAccount['account_number'] . ")\n";
    }
    
    $currentFeeSettings = $db->fetch("SELECT * FROM task_completion_points_fee_settings WHERE is_active = 1 LIMIT 1");
    if ($currentFeeSettings) {
        $feePercentage = (float)$currentFeeSettings['rate'] * 100;
        echo "✅ 手續費率: " . number_format($feePercentage, 2) . "% (" . $currentFeeSettings['description'] . ")\n";
    }
    
    echo "\n🎉 錢包 API 修復完成！\n";
    echo "現在應該可以正常使用錢包頁面了。\n\n";
    
    // 5. API 端點清單
    echo "📋 錢包 API 端點清單:\n";
    echo "- GET /api/wallet/summary.php - 錢包統計\n";
    echo "- GET /api/wallet/fee-settings.php - 手續費設定\n";
    echo "- GET /api/wallet/bank-accounts.php - 銀行帳戶資訊\n";
    echo "- GET /api/wallet/transactions.php - 交易記錄\n";
    
} catch (Exception $e) {
    echo "❌ 錯誤: " . $e->getMessage() . "\n";
    error_log("Wallet tables fix error: " . $e->getMessage());
}
?>

