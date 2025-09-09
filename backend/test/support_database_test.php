<?php
/**
 * 客服聊天室資料庫功能測試
 * 
 * 直接測試資料庫操作，不依賴 HTTP API
 */

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../utils/Response.php';

// 測試用戶 ID
$testUserId = 999;
$testAdminId = 998;

echo "🧪 開始客服聊天室資料庫功能測試\n";
echo "測試時間: " . date('Y-m-d H:i:s') . "\n";
echo str_repeat('=', 60) . "\n\n";

try {
    $db = Database::getInstance()->getConnection();
    
    // 清理測試數據
    echo "🧹 清理測試數據...\n";
    cleanupTestData($db, $testUserId, $testAdminId);
    echo "✅ 測試數據清理完成\n\n";
    
    // 建立測試用戶
    echo "👤 建立測試用戶...\n";
    setupTestUser($db, $testUserId);
    echo "✅ 測試用戶建立完成\n\n";
    
    // 測試 1: 資料庫表結構檢查
    echo "📝 測試 1: 檢查資料庫表結構\n";
    $tablesExist = checkDatabaseTables($db);
    if ($tablesExist) {
        echo "✅ 所有必要的資料庫表都存在\n";
    } else {
        echo "❌ 部分資料庫表缺失\n";
        exit(1);
    }
    echo "\n";
    
    // 測試 2: 建立客服事件
    echo "📝 測試 2: 建立客服事件\n";
    $roomId = createSupportEvent($db, $testUserId, 'Test Support Case', 'Test description');
    if ($roomId) {
        echo "✅ 客服事件建立成功，聊天室 ID: $roomId\n";
    } else {
        echo "❌ 客服事件建立失敗\n";
        exit(1);
    }
    echo "\n";
    
    // 測試 3: 檢查單一進行中事件限制
    echo "📝 測試 3: 檢查單一進行中事件限制\n";
    $canCreateSecond = canCreateAnotherEvent($db, $testUserId);
    if (!$canCreateSecond) {
        echo "✅ 單一進行中事件限制正常運作\n";
    } else {
        echo "❌ 單一進行中事件限制未生效\n";
        exit(1);
    }
    echo "\n";
    
    // 測試 4: 管理員接手
    echo "📝 測試 4: 管理員接手\n";
    $actualAdminId = setupTestAdmin($db, $testAdminId);
    $claimSuccess = adminClaimEvent($db, $actualAdminId, $roomId);
    if ($claimSuccess) {
        echo "✅ 管理員接手成功\n";
    } else {
        echo "❌ 管理員接手失敗\n";
        exit(1);
    }
    echo "\n";
    
    // 測試 5: 檢查狀態變更
    echo "📝 測試 5: 檢查狀態變更\n";
    $eventStatus = getEventStatus($db, $roomId);
    if ($eventStatus === 'in_progress') {
        echo "✅ 事件狀態正確變更為 in_progress\n";
    } else {
        echo "❌ 事件狀態變更失敗，當前狀態: $eventStatus\n";
        exit(1);
    }
    echo "\n";
    
    // 測試 6: 客戶評分結案
    echo "📝 測試 6: 客戶評分結案\n";
    $resolveSuccess = resolveEvent($db, $roomId, 5, 'Great service!');
    if ($resolveSuccess) {
        echo "✅ 客戶評分結案成功\n";
    } else {
        echo "❌ 客戶評分結案失敗\n";
        exit(1);
    }
    echo "\n";
    
    // 測試 7: 檢查最終狀態
    echo "📝 測試 7: 檢查最終狀態\n";
    $finalStatus = getEventStatus($db, $roomId);
    if ($finalStatus === 'resolved') {
        echo "✅ 事件最終狀態正確為 resolved\n";
    } else {
        echo "❌ 事件最終狀態錯誤，當前狀態: $finalStatus\n";
        exit(1);
    }
    echo "\n";
    
    // 測試 8: 結案後可建立新事件
    echo "📝 測試 8: 結案後可建立新事件\n";
    $canCreateAfterResolve = canCreateAnotherEvent($db, $testUserId);
    if ($canCreateAfterResolve) {
        echo "✅ 結案後可以建立新事件\n";
    } else {
        echo "❌ 結案後仍無法建立新事件\n";
        exit(1);
    }
    echo "\n";
    
    // 清理測試數據
    echo "🧹 清理測試數據...\n";
    cleanupTestData($db, $testUserId, $actualAdminId ?? $testAdminId);
    echo "✅ 測試數據清理完成\n\n";
    
    echo "🎉 所有測試通過！客服聊天室資料庫功能正常\n";
    
} catch (Exception $e) {
    echo "❌ 測試失敗: " . $e->getMessage() . "\n";
    echo "Stack trace: " . $e->getTraceAsString() . "\n";
    exit(1);
}

/**
 * 檢查資料庫表結構
 */
function checkDatabaseTables($db) {
    $requiredTables = [
        'support_chat_rooms',
        'support_events', 
        'support_event_logs',
        'support_chat_messages'
    ];
    
    foreach ($requiredTables as $table) {
        $stmt = $db->query("SHOW TABLES LIKE '$table'");
        if ($stmt->rowCount() === 0) {
            echo "❌ 表 $table 不存在\n";
            return false;
        }
        echo "✓ 表 $table 存在\n";
    }
    
    return true;
}

/**
 * 建立客服事件
 */
function createSupportEvent($db, $userId, $title, $description) {
    try {
        $db->beginTransaction();
        
        // 建立聊天室 (使用數字 ID)
        $roomId = rand(900000, 999999); // 生成測試用的數字 ID
        $stmt1 = $db->prepare("
            INSERT INTO support_chat_rooms (id, creator_id, participant_id, type, created_at) 
            VALUES (?, ?, NULL, 'support', NOW())
        ");
        $stmt1->execute([$roomId, $userId]);
        
        // 建立事件
        $stmt2 = $db->prepare("
            INSERT INTO support_events (support_chat_room_id, user_id, title, description, status, created_at, updated_at) 
            VALUES (?, ?, ?, ?, 'submitted', NOW(), NOW())
        ");
        $stmt2->execute([$roomId, $userId, $title, $description]);
        
        $db->commit();
        return $roomId;
        
    } catch (Exception $e) {
        $db->rollback();
        echo "建立客服事件錯誤: " . $e->getMessage() . "\n";
        return false;
    }
}

/**
 * 檢查是否可以建立另一個事件
 */
function canCreateAnotherEvent($db, $userId) {
    $stmt = $db->prepare("
        SELECT COUNT(*) as count 
        FROM support_events 
        WHERE user_id = ? AND status IN ('submitted', 'in_progress')
    ");
    $stmt->execute([$userId]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    return $result['count'] == 0;
}

/**
 * 設置測試用戶
 */
function setupTestUser($db, $userId) {
    $stmt = $db->prepare("
        INSERT INTO users (id, name, email, permission) 
        VALUES (?, 'Test User', 'user@test.com', 1) 
        ON DUPLICATE KEY UPDATE permission = 1
    ");
    $stmt->execute([$userId]);
}

/**
 * 設置測試管理員
 */
function setupTestAdmin($db, $adminId) {
    // 在 admins 表中建立測試管理員 (不指定 id，讓 AUTO_INCREMENT 處理)
    $username = 'testadmin_' . $adminId;
    $email = 'admin' . $adminId . '@test.com';
    
    $stmt = $db->prepare("
        INSERT INTO admins (username, email, password, full_name, role_id, status) 
        VALUES (?, ?, 'password_hash', 'Test Admin', NULL, 'active') 
        ON DUPLICATE KEY UPDATE status = 'active'
    ");
    $stmt->execute([$username, $email]);
    
    // 獲取插入的 ID
    return $db->lastInsertId();
}

/**
 * 管理員接手事件
 */
function adminClaimEvent($db, $adminId, $roomId) {
    try {
        $db->beginTransaction();
        
        // 更新聊天室 participant_id
        $stmt1 = $db->prepare("UPDATE support_chat_rooms SET participant_id = ? WHERE id = ?");
        $stmt1->execute([$adminId, $roomId]);
        
        // 更新事件狀態
        $stmt2 = $db->prepare("UPDATE support_events SET status = 'in_progress', admin_id = ?, updated_at = NOW() WHERE support_chat_room_id = ?");
        $stmt2->execute([$adminId, $roomId]);
        
        // 記錄事件日誌
        $stmt3 = $db->prepare("
            INSERT INTO support_event_logs (event_id, old_status, new_status, admin_id, created_at) 
            SELECT id, 'submitted', 'in_progress', ?, NOW() 
            FROM support_events WHERE support_chat_room_id = ?
        ");
        $stmt3->execute([$adminId, $roomId]);
        
        $db->commit();
        return true;
        
    } catch (Exception $e) {
        $db->rollback();
        echo "管理員接手錯誤: " . $e->getMessage() . "\n";
        return false;
    }
}

/**
 * 獲取事件狀態
 */
function getEventStatus($db, $roomId) {
    $stmt = $db->prepare("SELECT status FROM support_events WHERE support_chat_room_id = ?");
    $stmt->execute([$roomId]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    return $result ? $result['status'] : null;
}

/**
 * 結案事件
 */
function resolveEvent($db, $roomId, $rating, $review) {
    try {
        $db->beginTransaction();
        
        // 更新事件狀態和評分
        $stmt1 = $db->prepare("
            UPDATE support_events 
            SET status = 'resolved', rating = ?, review = ?, updated_at = NOW() 
            WHERE support_chat_room_id = ?
        ");
        $stmt1->execute([$rating, $review, $roomId]);
        
        // 記錄事件日誌
        $stmt2 = $db->prepare("
            INSERT INTO support_event_logs (event_id, old_status, new_status, created_at) 
            SELECT id, 'in_progress', 'resolved', NOW() 
            FROM support_events WHERE support_chat_room_id = ?
        ");
        $stmt2->execute([$roomId]);
        
        $db->commit();
        return true;
        
    } catch (Exception $e) {
        $db->rollback();
        echo "結案事件錯誤: " . $e->getMessage() . "\n";
        return false;
    }
}

/**
 * 清理測試數據
 */
function cleanupTestData($db, $testUserId, $testAdminId) {
    try {
        // 刪除測試事件
        $stmt1 = $db->prepare("DELETE FROM support_events WHERE user_id = ?");
        $stmt1->execute([$testUserId]);
        
        // 刪除測試聊天室
        $stmt2 = $db->prepare("DELETE FROM support_chat_rooms WHERE creator_id = ?");
        $stmt2->execute([$testUserId]);
        
        // 刪除測試訊息 (根據 room_id 範圍)
        $stmt3 = $db->prepare("DELETE FROM support_chat_messages WHERE room_id BETWEEN 900000 AND 999999");
        $stmt3->execute();
        
        // 刪除測試用戶
        $stmt4 = $db->prepare("DELETE FROM users WHERE id = ?");
        $stmt4->execute([$testUserId]);
        
        // 刪除測試管理員
        $stmt5 = $db->prepare("DELETE FROM admins WHERE id = ?");
        $stmt5->execute([$testAdminId]);
        
    } catch (Exception $e) {
        echo "清理數據錯誤: " . $e->getMessage() . "\n";
    }
}
?>
