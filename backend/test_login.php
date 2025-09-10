<?php
require_once 'config/database.php';

try {
    $db = Database::getInstance()->getConnection();
    $stmt = $db->prepare('SELECT id, name, email, password, permission, status FROM users WHERE email = ?');
    $stmt->execute(['linda@test.com']);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($user) {
        echo "用戶資訊:\n";
        echo "ID: {$user['id']}\n";
        echo "Name: {$user['name']}\n";
        echo "Email: {$user['email']}\n";
        echo "Permission: {$user['permission']}\n";
        echo "Status: {$user['status']}\n";
        echo "Password Hash: " . substr($user['password'], 0, 20) . "...\n";
        echo "Password Length: " . strlen($user['password']) . "\n";
        
        // 測試常見密碼
        $testPasswords = ['password', 'admin', '123456', 'linda', 'test'];
        echo "\n測試密碼:\n";
        foreach ($testPasswords as $pwd) {
            if (password_verify($pwd, $user['password'])) {
                echo "✅ 密碼 '{$pwd}' 驗證成功!\n";
            } else {
                echo "❌ 密碼 '{$pwd}' 驗證失敗\n";
            }
        }
        
        // 檢查是否為bcrypt hash
        if (password_get_info($user['password'])['algo']) {
            echo "\n密碼使用了 " . password_get_info($user['password'])['algoName'] . " 加密\n";
        } else {
            echo "\n密碼可能使用了舊的加密方式或未加密\n";
        }
        
    } else {
        echo "用戶不存在\n";
    }
} catch (Exception $e) {
    echo "錯誤: " . $e->getMessage() . "\n";
}
?>
