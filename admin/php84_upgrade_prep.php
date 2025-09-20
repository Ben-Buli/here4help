<?php
/**
 * Admin PHP 8.4 升級準備腳本
 * 檢查 Laravel 9 升級到 PHP 8.4 的準備工作
 * 
 * @author Here4Help Team
 * @version 1.0.0
 * @since 2024-09-19
 */

echo "🚀 Admin PHP 8.4 升級準備檢查\n";
echo "================================\n\n";

$checks = [];
$errors = [];
$warnings = [];

// 檢查 1：PHP 版本
echo "📋 檢查 1：PHP 環境\n";
$phpVersion = phpversion();
echo "PHP 版本: $phpVersion\n";

if (version_compare($phpVersion, '8.2.0', '<')) {
    $errors[] = "PHP 版本過低，Laravel 9 需要 PHP 8.2+";
} else {
    $checks[] = "✅ PHP 版本符合 Laravel 9 要求";
    
    if (version_compare($phpVersion, '8.4.0', '>=')) {
        $checks[] = "✅ PHP 8.4+ 版本，但 Laravel 9 不支援";
        $warnings[] = "⚠️ Laravel 9 不支援 PHP 8.4，需要升級到 Laravel 11";
    } elseif (version_compare($phpVersion, '8.3.0', '>=')) {
        $warnings[] = "建議升級至 PHP 8.4 以獲得最佳性能";
    }
}

echo "\n";

// 檢查 2：Laravel 版本
echo "📋 檢查 2：Laravel 框架\n";
if (file_exists('vendor/laravel/framework/composer.json')) {
    $laravelComposer = json_decode(file_get_contents('vendor/laravel/framework/composer.json'), true);
    $laravelVersion = $laravelComposer['version'] ?? 'unknown';
    echo "Laravel 版本: $laravelVersion\n";
    
    if (version_compare($laravelVersion, '9.0.0', '>=') && version_compare($laravelVersion, '10.0.0', '<')) {
        $checks[] = "✅ Laravel 9.x 版本";
        $warnings[] = "⚠️ Laravel 9 不支援 PHP 8.4，需要升級到 Laravel 11";
    } elseif (version_compare($laravelVersion, '11.0.0', '>=')) {
        $checks[] = "✅ Laravel 11+ 版本，支援 PHP 8.4";
    } else {
        $errors[] = "Laravel 版本過舊，需要升級";
    }
} else {
    $errors[] = "無法找到 Laravel 框架";
}

echo "\n";

// 檢查 3：Composer 依賴
echo "📋 檢查 3：Composer 依賴\n";
if (file_exists('composer.json')) {
    $composer = json_decode(file_get_contents('composer.json'), true);
    $phpRequirement = $composer['require']['php'] ?? 'unknown';
    echo "PHP 要求: $phpRequirement\n";
    
    if (strpos($phpRequirement, '^8.2') !== false) {
        $checks[] = "✅ Composer PHP 要求符合";
        $warnings[] = "需要更新為 ^8.4 以支援 PHP 8.4";
    } elseif (strpos($phpRequirement, '^8.4') !== false) {
        $checks[] = "✅ Composer PHP 要求已更新為 8.4";
    } else {
        $warnings[] = "Composer PHP 要求可能需要更新";
    }
} else {
    $errors[] = "無法找到 composer.json";
}

echo "\n";

// 檢查 4：相容性配置
echo "📋 檢查 4：相容性配置\n";
if (file_exists('php84_compatibility.php')) {
    $checks[] = "✅ PHP 8.4 相容性配置檔案已存在";
} else {
    $warnings[] = "缺少 php84_compatibility.php 配置檔案";
}

echo "\n";

// 檢查 5：備份狀態
echo "📋 檢查 5：備份狀態\n";
if (file_exists('../admin_0919_before_updateToPHP8.4/')) {
    $checks[] = "✅ 備份目錄已存在";
} else {
    $warnings[] = "建議在升級前創建備份";
}

echo "\n";

// 總結
echo "📊 檢查結果總結\n";
echo "================\n";

if (!empty($checks)) {
    echo "✅ 通過項目:\n";
    foreach ($checks as $check) {
        echo "   $check\n";
    }
    echo "\n";
}

if (!empty($warnings)) {
    echo "⚠️ 警告項目:\n";
    foreach ($warnings as $warning) {
        echo "   $warning\n";
    }
    echo "\n";
}

if (!empty($errors)) {
    echo "❌ 錯誤項目:\n";
    foreach ($errors as $error) {
        echo "   $error\n";
    }
    echo "\n";
}

// 升級建議
echo "🎯 升級建議\n";
echo "==========\n";

if (empty($errors)) {
    echo "✅ 基本環境檢查通過\n";
    echo "📋 建議升級步驟:\n";
    echo "   1. 升級 Laravel 9 → Laravel 11\n";
    echo "   2. 更新 composer.json 中的 PHP 要求\n";
    echo "   3. 運行 composer update\n";
    echo "   4. 測試所有功能\n";
    echo "   5. 部署到 PHP 8.4 環境\n";
} else {
    echo "❌ 請先解決錯誤項目再進行升級\n";
}

echo "\n";
echo "📚 參考資源:\n";
echo "   - Laravel 11 升級指南: https://laravel.com/docs/11.x/upgrade\n";
echo "   - PHP 8.4 發布說明: https://www.php.net/releases/8.4/\n";
echo "   - 備份位置: ../admin_0919_before_updateToPHP8.4/\n";

echo "\n";
echo "🔚 檢查完成\n";
?>
