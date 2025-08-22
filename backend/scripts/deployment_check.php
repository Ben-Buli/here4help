<?php
/**
 * 部署環境檢查腳本
 * 用於驗證 CPanel 部署環境是否正確配置
 */

echo "🚀 Here4Help 部署環境檢查\n";
echo "==========================\n\n";

$checks = [];
$errors = [];
$warnings = [];

// 檢查 1：PHP 版本和擴展
echo "📋 檢查 1：PHP 環境\n";
$phpVersion = phpversion();
echo "PHP 版本: $phpVersion\n";

if (version_compare($phpVersion, '7.4.0', '<')) {
    $errors[] = "PHP 版本過低，需要 7.4.0 或更高版本";
} else {
    $checks[] = "✅ PHP 版本符合要求";
}

$requiredExtensions = ['pdo_mysql', 'gd', 'curl', 'json', 'mbstring', 'openssl'];
foreach ($requiredExtensions as $ext) {
    if (extension_loaded($ext)) {
        $checks[] = "✅ $ext 擴展已載入";
    } else {
        $errors[] = "❌ $ext 擴展未載入";
    }
}

echo "\n";

// 檢查 2：環境變數
echo "📋 檢查 2：環境配置\n";
$envPath = __DIR__ . '/../config/.env';
if (file_exists($envPath)) {
    $checks[] = "✅ .env 檔案存在";
    
    // 載入環境變數
    require_once __DIR__ . '/../config/env_loader.php';
    EnvLoader::load();
    
    $requiredEnvVars = [
        'APP_ENV',
        'DB_HOST',
        'DB_NAME',
        'DB_USERNAME',
        'DB_PASSWORD',
        'JWT_SECRET'
    ];
    
    foreach ($requiredEnvVars as $var) {
        $value = EnvLoader::get($var);
        if ($value) {
            $checks[] = "✅ $var 已設置";
        } else {
            $errors[] = "❌ $var 未設置";
        }
    }
} else {
    $errors[] = "❌ .env 檔案不存在";
}

echo "\n";

// 檢查 3：資料庫連線
echo "📋 檢查 3：資料庫連線\n";
try {
    require_once __DIR__ . '/../config/database.php';
    $db = Database::getInstance();
    $result = $db->fetch("SELECT 1 as test");
    if ($result && $result['test'] == 1) {
        $checks[] = "✅ 資料庫連線成功";
    }
} catch (Exception $e) {
    $errors[] = "❌ 資料庫連線失敗: " . $e->getMessage();
}

echo "\n";

// 檢查 4：檔案權限
echo "📋 檢查 4：檔案權限\n";
$directories = [
    __DIR__ . '/../uploads' => '上傳目錄',
    __DIR__ . '/../logs' => '日誌目錄',
    __DIR__ . '/../cache' => '快取目錄'
];

foreach ($directories as $dir => $name) {
    if (!is_dir($dir)) {
        mkdir($dir, 0755, true);
        $warnings[] = "⚠️ $name 不存在，已自動創建";
    }
    
    if (is_writable($dir)) {
        $checks[] = "✅ $name 可寫入";
    } else {
        $errors[] = "❌ $name 無寫入權限";
    }
}

echo "\n";

// 檢查 5：HTTPS 配置
echo "📋 檢查 5：HTTPS 配置\n";
if (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') {
    $checks[] = "✅ HTTPS 已啟用";
} else {
    $warnings[] = "⚠️ HTTPS 未啟用 (開發環境可忽略)";
}

echo "\n";

// 檢查 6：API 端點測試
echo "📋 檢查 6：API 端點測試\n";
$apiEndpoints = [
    '/api/auth/test.php' => 'JWT 測試端點',
    '/api/media/test.php' => '媒體上傳測試端點',
    '/api/chat/test.php' => '聊天 API 測試端點'
];

foreach ($apiEndpoints as $endpoint => $name) {
    $fullPath = __DIR__ . '/..' . $endpoint;
    if (file_exists($fullPath)) {
        $checks[] = "✅ $name 檔案存在";
    } else {
        $warnings[] = "⚠️ $name 檔案不存在";
    }
}

echo "\n";

// 檢查 7：OAuth 配置
echo "📋 檢查 7：OAuth 配置\n";
$oauthVars = [
    'GOOGLE_CLIENT_ID_WEB' => 'Google OAuth Client ID',
    'FACEBOOK_APP_ID' => 'Facebook App ID',
    'APPLE_SERVICE_ID' => 'Apple Service ID'
];

foreach ($oauthVars as $var => $name) {
    $value = EnvLoader::get($var);
    if ($value && $value !== 'your_' . strtolower(str_replace('_', '_', $var))) {
        $checks[] = "✅ $name 已配置";
    } else {
        $warnings[] = "⚠️ $name 未配置或使用預設值";
    }
}

echo "\n";

// 檢查 8：安全設置
echo "📋 檢查 8：安全設置\n";
$htaccessPath = __DIR__ . '/../.htaccess';
if (file_exists($htaccessPath)) {
    $checks[] = "✅ .htaccess 檔案存在";
    
    $htaccessContent = file_get_contents($htaccessPath);
    if (strpos($htaccessContent, 'RewriteEngine On') !== false) {
        $checks[] = "✅ URL 重寫已啟用";
    } else {
        $warnings[] = "⚠️ URL 重寫可能未正確配置";
    }
    
    if (strpos($htaccessContent, 'HTTPS') !== false) {
        $checks[] = "✅ HTTPS 重定向已配置";
    } else {
        $warnings[] = "⚠️ HTTPS 重定向未配置";
    }
} else {
    $warnings[] = "⚠️ .htaccess 檔案不存在";
}

echo "\n";

// 檢查 9：Socket 伺服器 (可選)
echo "📋 檢查 9：Socket 伺服器\n";
$socketUrl = EnvLoader::get('SOCKET_URL');
if ($socketUrl) {
    $checks[] = "✅ Socket URL 已配置: $socketUrl";
    
    // 嘗試連接 Socket 伺服器
    $socketHost = parse_url($socketUrl, PHP_URL_HOST);
    $socketPort = parse_url($socketUrl, PHP_URL_PORT) ?: 3001;
    
    $connection = @fsockopen($socketHost, $socketPort, $errno, $errstr, 5);
    if ($connection) {
        $checks[] = "✅ Socket 伺服器可連接";
        fclose($connection);
    } else {
        $warnings[] = "⚠️ Socket 伺服器無法連接 (可能需要啟動或使用備用方案)";
    }
} else {
    $warnings[] = "⚠️ Socket URL 未配置";
}

echo "\n";

// 檢查 10：媒體處理
echo "📋 檢查 10：媒體處理\n";
if (extension_loaded('gd')) {
    $gdInfo = gd_info();
    $checks[] = "✅ GD 擴展已載入 (版本: " . $gdInfo['GD Version'] . ")";
    
    $supportedFormats = [];
    if ($gdInfo['JPEG Support']) $supportedFormats[] = 'JPEG';
    if ($gdInfo['PNG Support']) $supportedFormats[] = 'PNG';
    if ($gdInfo['GIF Read Support']) $supportedFormats[] = 'GIF';
    
    $checks[] = "✅ 支援的圖片格式: " . implode(', ', $supportedFormats);
} else {
    $errors[] = "❌ GD 擴展未載入";
}

$maxUploadSize = ini_get('upload_max_filesize');
$maxPostSize = ini_get('post_max_size');
$checks[] = "✅ 最大上傳檔案大小: $maxUploadSize";
$checks[] = "✅ 最大 POST 大小: $maxPostSize";

echo "\n";

// 總結報告
echo "📊 檢查總結\n";
echo "===========\n";
echo "✅ 通過檢查: " . count($checks) . " 項\n";
echo "⚠️ 警告: " . count($warnings) . " 項\n";
echo "❌ 錯誤: " . count($errors) . " 項\n\n";

if (!empty($checks)) {
    echo "✅ 通過的檢查:\n";
    foreach ($checks as $check) {
        echo "  $check\n";
    }
    echo "\n";
}

if (!empty($warnings)) {
    echo "⚠️ 警告項目:\n";
    foreach ($warnings as $warning) {
        echo "  $warning\n";
    }
    echo "\n";
}

if (!empty($errors)) {
    echo "❌ 需要修復的錯誤:\n";
    foreach ($errors as $error) {
        echo "  $error\n";
    }
    echo "\n";
}

// 部署建議
echo "💡 部署建議\n";
echo "==========\n";

if (empty($errors)) {
    echo "🎉 恭喜！環境檢查通過，可以進行部署。\n\n";
    
    echo "📋 部署步驟建議:\n";
    echo "1. 備份現有資料庫和檔案\n";
    echo "2. 上傳檔案到 CPanel\n";
    echo "3. 設置資料庫連線\n";
    echo "4. 配置 .htaccess 和權限\n";
    echo "5. 測試 API 功能\n";
    echo "6. 設置 SSL 憑證\n";
    echo "7. 配置監控和備份\n";
} else {
    echo "⚠️ 請先修復上述錯誤後再進行部署。\n";
}

if (!empty($warnings)) {
    echo "\n📝 注意事項:\n";
    echo "- 警告項目不會阻止部署，但建議在正式環境中處理\n";
    echo "- Socket 伺服器如果無法啟動，可以使用長輪詢備用方案\n";
    echo "- OAuth 配置可以在部署後再設置\n";
}

echo "\n🔗 相關文檔:\n";
echo "- 部署指南: docs/優先執行/部署高階專案指南.md\n";
echo "- 環境配置: backend/config/README_ENV_SETUP.md\n";
echo "- 故障排除: docs/TROUBLESHOOTING.md\n";

echo "\n" . date('Y-m-d H:i:s') . " - 檢查完成\n";
?>
