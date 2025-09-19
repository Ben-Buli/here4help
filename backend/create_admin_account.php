<?php
/**
 * 建立管理員帳號腳本
 * 用於在 admins 資料表中新增管理員帳號
 */

require_once 'config/database.php';

try {
    $db = Database::getInstance()->getConnection();
    
    // 管理員帳號資訊
    $username = 'admin';
    $email = 'admin@here4help.com';
    $password = 'Admin123!@#';  // 強密碼：包含大小寫字母、數字和特殊符號
    $fullName = '系統管理員';
    $roleId = 1;  // 管理員角色 ID
    $status = 'active';
    
    echo "=== 建立管理員帳號 ===\n";
    echo "帳號資訊:\n";
    echo "Username: {$username}\n";
    echo "Email: {$email}\n";
    echo "Full Name: {$fullName}\n";
    echo "Role ID: {$roleId}\n";
    echo "Status: {$status}\n";
    echo "Password: {$password}\n\n";
    
    // 檢查管理員是否已存在
    $checkStmt = $db->prepare('SELECT id FROM admins WHERE email = ? OR username = ?');
    $checkStmt->execute([$email, $username]);
    
    if ($checkStmt->fetch()) {
        echo "❌ 管理員帳號已存在 (email: {$email} 或 username: {$username})\n";
        echo "是否要更新密碼？(y/n): ";
        $handle = fopen("php://stdin", "r");
        $line = fgets($handle);
        fclose($handle);
        
        if (trim($line) === 'y' || trim($line) === 'Y') {
            // 更新現有管理員的密碼
            $hashedPassword = password_hash($password, PASSWORD_DEFAULT);
            
            $updateStmt = $db->prepare('
                UPDATE admins 
                SET password = ?, updated_at = NOW() 
                WHERE email = ? OR username = ?
            ');
            $updateStmt->execute([$hashedPassword, $email, $username]);
            
            echo "✅ 管理員密碼已更新\n";
        } else {
            echo "操作已取消\n";
            exit(0);
        }
    } else {
        echo "建立新的管理員帳號...\n";
        
        // 加密密碼
        $hashedPassword = password_hash($password, PASSWORD_DEFAULT);
        
        // 建立新管理員
        $insertStmt = $db->prepare('
            INSERT INTO admins (username, email, password, full_name, role_id, status, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())
        ');
        $insertStmt->execute([
            $username,
            $email,
            $hashedPassword,
            $fullName,
            $roleId,
            $status
        ]);
        
        echo "✅ 新管理員帳號已建立\n";
    }
    
    // 驗證建立結果
    $verifyStmt = $db->prepare('
        SELECT a.id, a.username, a.full_name, a.email, a.role_id, a.status, a.created_at, a.updated_at,
               ar.name as role_name
        FROM admins a
        LEFT JOIN admin_roles ar ON a.role_id = ar.id
        WHERE a.email = ?
    ');
    $verifyStmt->execute([$email]);
    $admin = $verifyStmt->fetch(PDO::FETCH_ASSOC);
    
    if ($admin) {
        echo "\n✅ 驗證成功，管理員資訊:\n";
        echo "ID: {$admin['id']}\n";
        echo "Username: {$admin['username']}\n";
        echo "Full Name: {$admin['full_name']}\n";
        echo "Email: {$admin['email']}\n";
        echo "Role ID: {$admin['role_id']}\n";
        echo "Role Name: " . ($admin['role_name'] ?? 'N/A') . "\n";
        echo "Status: {$admin['status']}\n";
        echo "Created: {$admin['created_at']}\n";
        echo "Updated: {$admin['updated_at']}\n";
        
        // 測試密碼驗證
        echo "\n=== 密碼驗證測試 ===\n";
        $testStmt = $db->prepare('SELECT password FROM admins WHERE email = ?');
        $testStmt->execute([$email]);
        $storedPassword = $testStmt->fetchColumn();
        
        if (password_verify($password, $storedPassword)) {
            echo "✅ 密碼驗證成功\n";
        } else {
            echo "❌ 密碼驗證失敗\n";
        }
        
        echo "\n=== 登入資訊 ===\n";
        echo "管理員後台登入網址: /admin/login\n";
        echo "Email: {$email}\n";
        echo "Password: {$password}\n";
        echo "\n⚠️  請妥善保管登入資訊，建議首次登入後立即修改密碼\n";
        
    } else {
        echo "❌ 驗證失敗，無法找到建立的管理員帳號\n";
    }
    
} catch (Exception $e) {
    echo "❌ 錯誤: " . $e->getMessage() . "\n";
    echo "錯誤詳情: " . $e->getTraceAsString() . "\n";
}
?>
