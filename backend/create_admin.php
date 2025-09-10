<?php
require_once 'config/database.php';

try {
    $db = Database::getInstance()->getConnection();
    
    // 創建測試管理員用戶
    $email = 'admin@here4help.com';
    $password = 'admin123';
    $name = 'Test Admin';
    $permission = 99;
    $status = 'active';
    
    // 檢查用戶是否已存在
    $checkStmt = $db->prepare('SELECT id FROM users WHERE email = ?');
    $checkStmt->execute([$email]);
    
    if ($checkStmt->fetch()) {
        echo "用戶 {$email} 已存在，更新密碼...\n";
        
        // 更新現有用戶的密碼和權限
        $updateStmt = $db->prepare('
            UPDATE users 
            SET password = ?, permission = ?, status = ?, updated_at = NOW() 
            WHERE email = ?
        ');
        $updateStmt->execute([
            password_hash($password, PASSWORD_DEFAULT),
            $permission,
            $status,
            $email
        ]);
        
        echo "✅ 用戶密碼已更新\n";
    } else {
        echo "創建新的管理員用戶...\n";
        
        // 創建新用戶
        $insertStmt = $db->prepare('
            INSERT INTO users (name, email, password, permission, status, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, NOW(), NOW())
        ');
        $insertStmt->execute([
            $name,
            $email,
            password_hash($password, PASSWORD_DEFAULT),
            $permission,
            $status
        ]);
        
        echo "✅ 新管理員用戶已創建\n";
    }
    
    echo "\n管理員登入資訊:\n";
    echo "Email: {$email}\n";
    echo "Password: {$password}\n";
    echo "Permission: {$permission}\n";
    echo "Status: {$status}\n";
    
    // 驗證創建結果
    $verifyStmt = $db->prepare('SELECT id, name, email, permission, status FROM users WHERE email = ?');
    $verifyStmt->execute([$email]);
    $user = $verifyStmt->fetch(PDO::FETCH_ASSOC);
    
    if ($user) {
        echo "\n✅ 驗證成功，用戶資訊:\n";
        echo "ID: {$user['id']}\n";
        echo "Name: {$user['name']}\n";
        echo "Email: {$user['email']}\n";
        echo "Permission: {$user['permission']}\n";
        echo "Status: {$user['status']}\n";
    }
    
} catch (Exception $e) {
    echo "錯誤: " . $e->getMessage() . "\n";
}
?>
