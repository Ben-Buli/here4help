<?php
/**
 * 生成測試密碼的 bcrypt 雜湊
 * 用於手動更新 users 表中的測試帳號密碼
 */

// 測試密碼列表
$testPasswords = [
    'Aa12345',  // 用戶提供的範例密碼
    'Test123',  // 額外的測試密碼選項
    'Admin123', // 管理員測試密碼
];

echo "========================================\n";
echo "測試密碼 bcrypt 雜湊生成器\n";
echo "========================================\n\n";

echo "📝 MySQL UPDATE 語句（可直接執行）:\n";
echo str_repeat("=", 100) . "\n\n";

foreach ($testPasswords as $password) {
    // 生成 bcrypt 雜湊
    $hashedPassword = password_hash($password, PASSWORD_DEFAULT);
    
    // 轉義單引號以用於 SQL
    $escapedHash = addslashes($hashedPassword);
    
    echo "-- 密碼: {$password}\n";
    echo "-- 雜湊: {$hashedPassword}\n";
    echo "-- 使用方式: UPDATE users SET password = '{$escapedHash}' WHERE email = 'your_test_email@example.com';\n\n";
}

echo str_repeat("=", 100) . "\n\n";

echo "📋 驗證雜湊（可選）:\n";
echo str_repeat("=", 100) . "\n";
foreach ($testPasswords as $password) {
    $hashedPassword = password_hash($password, PASSWORD_DEFAULT);
    $isValid = password_verify($password, $hashedPassword);
    echo "密碼: {$password} - 驗證: " . ($isValid ? "✅ 成功" : "❌ 失敗") . "\n";
}

echo "\n";
echo "✅ 完成！請將上述 UPDATE 語句中的 'your_test_email@example.com' 替換為實際的測試帳號 email。\n";
?>

