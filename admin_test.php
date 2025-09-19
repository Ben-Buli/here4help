<?php
// Admin 測試頁面
echo "Admin Laravel 測試頁面<br>";
echo "PHP 版本: " . phpversion() . "<br>";
echo "當前時間: " . date('Y-m-d H:i:s') . "<br>";

// 檢查 .env 檔案
if (file_exists('.env')) {
    echo "✅ .env 檔案存在<br>";
} else {
    echo "❌ .env 檔案不存在<br>";
}

// 檢查 Laravel 檔案
if (file_exists('bootstrap/app.php')) {
    echo "✅ Laravel bootstrap 檔案存在<br>";
} else {
    echo "❌ Laravel bootstrap 檔案不存在<br>";
}

// 檢查 vendor 目錄
if (is_dir('vendor')) {
    echo "✅ vendor 目錄存在<br>";
} else {
    echo "❌ vendor 目錄不存在<br>";
}

// 檢查 storage 目錄
if (is_dir('storage')) {
    echo "✅ storage 目錄存在<br>";
    if (is_writable('storage')) {
        echo "✅ storage 目錄可寫入<br>";
    } else {
        echo "❌ storage 目錄不可寫入<br>";
    }
} else {
    echo "❌ storage 目錄不存在<br>";
}

// 檢查 public 目錄
if (is_dir('public')) {
    echo "✅ public 目錄存在<br>";
} else {
    echo "❌ public 目錄不存在<br>";
}

echo "<br>測試完成！";
?>
