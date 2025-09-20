<?php
/**
 * 批量更新 API 端點以支援 PHP 8.4
 * 自動在所有 API 檔案開頭添加相容性配置載入
 */

echo "🚀 開始批量更新 API 端點以支援 PHP 8.4\n";
echo "==========================================\n\n";

$apiDir = __DIR__ . '/../api';
$updatedFiles = [];
$skippedFiles = [];

// 遞歸掃描 API 目錄
function scanApiFiles($dir, &$updatedFiles, &$skippedFiles) {
    $files = glob($dir . '/*.php');
    
    foreach ($files as $file) {
        $relativePath = str_replace(__DIR__ . '/../', '', $file);
        echo "處理檔案: $relativePath\n";
        
        $content = file_get_contents($file);
        
        // 檢查是否已經載入相容性配置
        if (strpos($content, 'php84_compatibility.php') !== false) {
            echo "  ⏭️  已包含相容性配置，跳過\n";
            $skippedFiles[] = $relativePath;
            continue;
        }
        
        // 檢查是否為 PHP 檔案
        if (strpos($content, '<?php') !== 0) {
            echo "  ⏭️  不是標準 PHP 檔案，跳過\n";
            $skippedFiles[] = $relativePath;
            continue;
        }
        
        // 計算相對路徑深度
        $depth = substr_count($relativePath, '/') - 1; // 減去 'api/' 本身
        $configPath = str_repeat('../', $depth) . 'config/php84_compatibility.php';
        
        // 在 <?php 後添加相容性配置載入
        $newContent = str_replace(
            '<?php',
            "<?php\n// 載入 PHP 8.4 相容性配置\nrequire_once __DIR__ . '/$configPath';\n",
            $content
        );
        
        // 寫回檔案
        if (file_put_contents($file, $newContent)) {
            echo "  ✅ 已更新\n";
            $updatedFiles[] = $relativePath;
        } else {
            echo "  ❌ 更新失敗\n";
        }
    }
    
    // 遞歸處理子目錄
    $subdirs = glob($dir . '/*', GLOB_ONLYDIR);
    foreach ($subdirs as $subdir) {
        scanApiFiles($subdir, $updatedFiles, $skippedFiles);
    }
}

// 開始掃描
scanApiFiles($apiDir, $updatedFiles, $skippedFiles);

// 輸出結果
echo "\n📊 更新結果總結\n";
echo "================\n";

echo "✅ 已更新檔案 (" . count($updatedFiles) . " 個):\n";
foreach ($updatedFiles as $file) {
    echo "   - $file\n";
}

echo "\n⏭️  跳過檔案 (" . count($skippedFiles) . " 個):\n";
foreach ($skippedFiles as $file) {
    echo "   - $file\n";
}

echo "\n🎯 下一步建議:\n";
echo "1. 測試所有 API 端點功能\n";
echo "2. 檢查錯誤日誌\n";
echo "3. 在 cPanel 中設置 PHP 8.4\n";
echo "4. 運行部署檢查腳本: php scripts/deployment_check.php\n";

echo "\n🔚 批量更新完成\n";
?>
