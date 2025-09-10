<?php
require_once 'config/database.php';

try {
    $db = Database::getInstance()->getConnection();
    
    // 檢查 admins 資料表結構
    echo "=== ADMINS 資料表結構 ===\n";
    $stmt = $db->prepare('DESCRIBE admins');
    $stmt->execute();
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($columns as $column) {
        echo "{$column['Field']}: {$column['Type']} {$column['Null']} {$column['Key']} {$column['Default']}\n";
    }
    
    echo "\n=== ADMINS 資料表內容 ===\n";
    $stmt = $db->prepare('SELECT * FROM admins ORDER BY id');
    $stmt->execute();
    $admins = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($admins)) {
        echo "❌ admins 資料表是空的\n";
    } else {
        echo "ID\tUsername\tEmail\t\t\tRole\tStatus\tCreated\n";
        echo "--\t--------\t-----\t\t\t----\t------\t-------\n";
        foreach ($admins as $admin) {
            $roleId = $admin['role_id'] ?? 'N/A';
            $status = $admin['status'] ?? 'N/A';
            $created = $admin['created_at'] ?? 'N/A';
            echo "{$admin['id']}\t{$admin['username']}\t{$admin['email']}\t{$roleId}\t{$status}\t{$created}\n";
        }
    }
    
    // 檢查 admin_roles 資料表
    echo "\n=== ADMIN_ROLES 資料表 ===\n";
    $stmt = $db->prepare('SELECT * FROM admin_roles ORDER BY id');
    $stmt->execute();
    $roles = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (!empty($roles)) {
        foreach ($roles as $role) {
            echo "Role ID {$role['id']}: {$role['name']} ({$role['display_name']})\n";
        }
    } else {
        echo "❌ admin_roles 資料表是空的\n";
    }
    
} catch (Exception $e) {
    echo "錯誤: " . $e->getMessage() . "\n";
}
?>
