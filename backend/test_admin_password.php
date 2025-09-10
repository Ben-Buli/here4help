<?php
require_once 'config/database.php';

$db = Database::getInstance()->getConnection();
$stmt = $db->prepare('SELECT username, email, password FROM admins WHERE email = ?');
$stmt->execute(['admin@here4help.com']);
$admin = $stmt->fetch(PDO::FETCH_ASSOC);

if ($admin) {
    echo "用戶: {$admin['username']}\n";
    echo "Email: {$admin['email']}\n";
    echo "Password Hash: " . substr($admin['password'], 0, 20) . "...\n";
    
    // 測試常見密碼
    $testPasswords = ['admin', 'password', '123456', 'admin123', 'here4help', 'test'];
    echo "\n測試密碼:\n";
    foreach ($testPasswords as $pwd) {
        if (password_verify($pwd, $admin['password'])) {
            echo "✅ 密碼 '{$pwd}' 驗證成功!\n";
        } else {
            echo "❌ 密碼 '{$pwd}' 驗證失敗\n";
        }
    }
} else {
    echo "管理員不存在\n";
}
?>
