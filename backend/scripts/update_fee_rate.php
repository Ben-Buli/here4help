<?php
/**
 * 更新費率設定腳本
 */

try {
    // 使用 MAMP socket 連接
    $dsn = "mysql:unix_socket=/Applications/MAMP/tmp/mysql/mysql.sock;dbname=hero4helpdemofhs_hero4help;charset=utf8mb4";
    $pdo = new PDO($dsn, 'root', 'root', [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    
    echo "Database connected successfully.\n";
    
    // 停用所有現有設定
    $pdo->exec("UPDATE task_completion_points_fee_settings SET is_active = 0");
    echo "Deactivated all existing settings.\n";
    
    // 插入新的 2% 費率設定
    $insertSQL = "
        INSERT INTO task_completion_points_fee_settings (
            rate, description, is_active, updated_by, created_at, updated_at
        ) VALUES (0.0200, 'Test 2% completion fee for Action Bar Logic', 1, NULL, NOW(), NOW())
    ";
    
    $pdo->exec($insertSQL);
    $settingsId = $pdo->lastInsertId();
    
    echo "New fee settings created with ID: $settingsId\n";
    echo "Rate: 2.00%\n";
    echo "Description: Test 2% completion fee for Action Bar Logic\n";
    
    // 顯示當前設定
    $stmt = $pdo->query("
        SELECT id, rate, description, is_active, created_at 
        FROM task_completion_points_fee_settings 
        WHERE is_active = 1 
        ORDER BY id DESC 
        LIMIT 1
    ");
    $currentSettings = $stmt->fetch();
    
    if ($currentSettings) {
        echo "\nCurrent active settings:\n";
        echo "ID: " . $currentSettings['id'] . "\n";
        echo "Rate: " . number_format((float)$currentSettings['rate'] * 100, 2) . "%\n";
        echo "Description: " . $currentSettings['description'] . "\n";
        echo "Active: " . ($currentSettings['is_active'] ? 'Yes' : 'No') . "\n";
        echo "Created: " . $currentSettings['created_at'] . "\n";
    }
    
    echo "\nFee rate updated successfully.\n";
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    exit(1);
}
?>
