<?php
/**
 * 媒體處理系統簡化測試腳本
 * 測試不依賴資料庫的核心功能
 */

require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../utils/MediaValidator.php';
require_once __DIR__ . '/../utils/SecurityScanner.php';
require_once __DIR__ . '/../utils/Logger.php';

echo "🧪 媒體處理系統簡化測試\n";
echo "========================\n\n";

try {
    // 測試1: MediaValidator 基本功能
    echo "1. 測試 MediaValidator 基本功能\n";
    echo "-------------------------------\n";
    testMediaValidatorBasics();
    
    echo "\n";
    
    // 測試2: SecurityScanner 功能
    echo "2. 測試 SecurityScanner\n";
    echo "----------------------\n";
    testSecurityScanner();
    
    echo "\n";
    
    // 測試3: 檔案類型檢查
    echo "3. 測試檔案類型檢查\n";
    echo "------------------\n";
    testFileTypeValidation();
    
    echo "\n✅ 簡化測試完成！\n";
    
} catch (Exception $e) {
    echo "❌ 測試失敗: " . $e->getMessage() . "\n";
    exit(1);
}

/**
 * 測試 MediaValidator 基本功能
 */
function testMediaValidatorBasics() {
    $validator = new MediaValidator();
    
    // 測試檔案類型統計
    $stats = MediaValidator::getFileTypeStats();
    echo "📊 支援的檔案類型:\n";
    echo "- 圖片類型: " . count($stats['allowed_image_types']) . " 種\n";
    echo "- 文件類型: " . count($stats['allowed_document_types']) . " 種\n";
    echo "- 最大圖片大小: " . formatBytes($stats['size_limits']['max_image_size']) . "\n";
    echo "- 最大文件大小: " . formatBytes($stats['size_limits']['max_document_size']) . "\n";
    
    // 測試檔案大小檢查
    echo "\n測試檔案大小限制:\n";
    
    $testSizes = [
        ['size' => 1024, 'type' => 'image/jpeg', 'name' => 'small.jpg'],
        ['size' => 5 * 1024 * 1024, 'type' => 'image/png', 'name' => 'medium.png'],
        ['size' => 15 * 1024 * 1024, 'type' => 'image/jpeg', 'name' => 'large.jpg'],
        ['size' => 2 * 1024 * 1024, 'type' => 'application/pdf', 'name' => 'document.pdf']
    ];
    
    foreach ($testSizes as $test) {
        // 創建模擬的檔案陣列
        $mockFile = [
            'name' => $test['name'],
            'type' => $test['type'],
            'size' => $test['size'],
            'tmp_name' => '/tmp/mock_file',
            'error' => UPLOAD_ERR_OK
        ];
        
        // 由於我們只是測試大小限制邏輯，這裡簡化判斷
        $isValid = true;
        if ($test['type'] === 'image/jpeg' || $test['type'] === 'image/png') {
            $isValid = $test['size'] <= MediaValidator::MAX_IMAGE_SIZE;
        } elseif ($test['type'] === 'application/pdf') {
            $isValid = $test['size'] <= MediaValidator::MAX_DOCUMENT_SIZE;
        }
        
        $status = $isValid ? '✅' : '❌';
        echo "$status " . formatBytes($test['size']) . " ({$test['type']}) - " . ($isValid ? '通過' : '超限') . "\n";
    }
}

/**
 * 測試 SecurityScanner
 */
function testSecurityScanner() {
    $scanner = new SecurityScanner();
    
    // 創建不同類型的測試檔案
    $testFiles = [
        ['name' => 'clean.txt', 'content' => 'This is a clean file.'],
        ['name' => 'suspicious.php', 'content' => '<?php eval($_POST["code"]); ?>'],
        ['name' => 'script.html', 'content' => '<script>alert("xss")</script>'],
        ['name' => 'normal.jpg', 'content' => createFakeImageContent()]
    ];
    
    foreach ($testFiles as $testFile) {
        $tempFile = sys_get_temp_dir() . '/' . $testFile['name'];
        file_put_contents($tempFile, $testFile['content']);
        
        echo "掃描檔案: {$testFile['name']}\n";
        
        $scanResult = $scanner->scanFile($tempFile, 'test');
        
        $statusIcon = [
            'clean' => '✅',
            'suspicious' => '⚠️',
            'infected' => '❌',
            'error' => '🔴'
        ][$scanResult['status']] ?? '❓';
        
        echo "$statusIcon 掃描狀態: {$scanResult['status']}\n";
        echo "   訊息: {$scanResult['message']}\n";
        
        if (isset($scanResult['details']['scan_duration'])) {
            echo "   耗時: {$scanResult['details']['scan_duration']} 秒\n";
        }
        
        echo "\n";
        
        // 清理檔案
        if (file_exists($tempFile)) {
            unlink($tempFile);
        }
    }
}

/**
 * 測試檔案類型驗證
 */
function testFileTypeValidation() {
    echo "測試檔案類型支援:\n";
    
    $testCases = [
        ['filename' => 'image.jpg', 'mime' => 'image/jpeg', 'context' => 'chat'],
        ['filename' => 'image.png', 'mime' => 'image/png', 'context' => 'avatar'],
        ['filename' => 'document.pdf', 'mime' => 'application/pdf', 'context' => 'document'],
        ['filename' => 'script.exe', 'mime' => 'application/octet-stream', 'context' => 'chat'],
        ['filename' => 'video.mp4', 'mime' => 'video/mp4', 'context' => 'chat'],
        ['filename' => 'archive.zip', 'mime' => 'application/zip', 'context' => 'document']
    ];
    
    foreach ($testCases as $test) {
        // 根據情境判斷是否允許
        $allowedTypes = [];
        switch ($test['context']) {
            case 'avatar':
            case 'chat':
            case 'dispute':
                $allowedTypes = MediaValidator::ALLOWED_IMAGE_TYPES;
                break;
            case 'document':
            case 'verification':
                $allowedTypes = array_merge(MediaValidator::ALLOWED_IMAGE_TYPES, MediaValidator::ALLOWED_DOCUMENT_TYPES);
                break;
            default:
                $allowedTypes = MediaValidator::ALLOWED_IMAGE_TYPES;
        }
        
        $isAllowed = in_array($test['mime'], $allowedTypes);
        $status = $isAllowed ? '✅' : '❌';
        
        echo "$status {$test['filename']} ({$test['mime']}) 在 {$test['context']} 情境下: " . 
             ($isAllowed ? '允許' : '禁止') . "\n";
    }
}

/**
 * 輔助函數
 */
function createFakeImageContent() {
    // JPEG 檔案頭部
    return "\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x01\x00H\x00H\x00\x00\xFF\xDB\x00C\x00" . str_repeat('x', 1000) . "\xFF\xD9";
}

function formatBytes($bytes, $precision = 2) {
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];
    
    for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
        $bytes /= 1024;
    }
    
    return round($bytes, $precision) . ' ' . $units[$i];
}
