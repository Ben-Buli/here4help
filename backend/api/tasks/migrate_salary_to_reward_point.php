<?php
/**
 * 資料庫遷移腳本：將 salary 欄位重命名為 reward_point
 * 執行此腳本前請先備份資料庫
 */

require_once '../../config/database.php';
require_once '../../utils/TokenValidator.php';

try {
    $db = Database::getInstance();
    
    echo "開始遷移 salary 欄位到 reward_point...\n";
    
    // 檢查是否存在 salary 欄位
    $checkColumnSql = "SHOW COLUMNS FROM tasks LIKE 'salary'";
    $salaryColumn = $db->fetch($checkColumnSql);
    
    if ($salaryColumn) {
        echo "找到 salary 欄位，開始遷移...\n";
        
        // 檢查是否已存在 reward_point 欄位
        $checkRewardPointSql = "SHOW COLUMNS FROM tasks LIKE 'reward_point'";
        $rewardPointColumn = $db->fetch($checkRewardPointSql);
        
        if (!$rewardPointColumn) {
            // 添加 reward_point 欄位
            echo "添加 reward_point 欄位...\n";
            $addColumnSql = "ALTER TABLE tasks ADD COLUMN reward_point VARCHAR(10) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '0' AFTER description";
            $db->query($addColumnSql);
            echo "✓ reward_point 欄位已添加\n";
        }
        
        // 將 salary 欄位的數據複製到 reward_point 欄位
        echo "複製 salary 數據到 reward_point...\n";
        $copyDataSql = "UPDATE tasks SET reward_point = salary WHERE salary IS NOT NULL AND salary != ''";
        $db->query($copyDataSql);
        echo "✓ 數據已複製\n";
        
        // 刪除 salary 欄位（可選，建議先保留一段時間）
        echo "是否要刪除 salary 欄位？(y/n): ";
        $handle = fopen("php://stdin", "r");
        $line = fgets($handle);
        fclose($handle);
        
        if (trim($line) === 'y' || trim($line) === 'Y') {
            $dropColumnSql = "ALTER TABLE tasks DROP COLUMN salary";
            $db->query($dropColumnSql);
            echo "✓ salary 欄位已刪除\n";
        } else {
            echo "保留 salary 欄位以確保向後兼容性\n";
        }
        
    } else {
        echo "未找到 salary 欄位，檢查是否已存在 reward_point 欄位...\n";
        
        $checkRewardPointSql = "SHOW COLUMNS FROM tasks LIKE 'reward_point'";
        $rewardPointColumn = $db->fetch($checkRewardPointSql);
        
        if (!$rewardPointColumn) {
            echo "添加 reward_point 欄位...\n";
            $addColumnSql = "ALTER TABLE tasks ADD COLUMN reward_point VARCHAR(10) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '0' AFTER description";
            $db->query($addColumnSql);
            echo "✓ reward_point 欄位已添加\n";
        } else {
            echo "✓ reward_point 欄位已存在\n";
        }
    }
    
    echo "\n遷移完成！\n";
    echo "請確保更新所有相關的 API 和前端代碼以使用 reward_point 欄位。\n";
    
} catch (Exception $e) {
    echo "遷移失敗: " . $e->getMessage() . "\n";
    echo "請檢查資料庫連接和權限。\n";
}
?> 