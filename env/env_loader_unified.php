<?php
/**
 * 統一環境配置載入器 (備份版本)
 * 此檔案已整合到 backend/config/env_loader.php
 * 保留此檔案作為參考，實際使用 backend/config/env_loader.php
 * 
 * @deprecated 請使用 backend/config/env_loader.php
 */

// 防止直接使用此檔案
if (basename(__FILE__) === basename($_SERVER['SCRIPT_NAME'])) {
    die('此檔案已廢棄，請使用 backend/config/env_loader.php');
}

// 如果類別尚未定義，則定義一個簡單的別名
if (!class_exists('EnvLoader')) {
    // 重新導向到 Backend 載入器
    require_once __DIR__ . '/../backend/config/env_loader.php';
}
?>
