<?php
/**
 * 管理員接手流程測試
 * 
 * 測試項目：
 * 1. 管理員可以接手 submitted 狀態的客服事件
 * 2. 接手後狀態變為 in_progress
 * 3. participant_id 正確設置
 * 4. 系統訊息正確發送
 */

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../utils/Response.php';

// 測試用戶 ID
$testUserId = 998;
$testAdminId = 997;
$testTitle = 'Test Admin Claim Flow';
$testDescription = 'This is a test for admin claim flow.';

echo "🧪 開始管理員接手流程測試\n";
echo "測試用戶 ID: $testUserId\n";
echo "測試管理員 ID: $testAdminId\n\n";

try {
    $db = Database::getInstance()->getConnection();
    
    // 清理測試數據
    echo "🧹 清理測試數據...\n";
    $stmt1 = $db->prepare("DELETE FROM support_events WHERE user_id = ?");
    $stmt1->execute([$testUserId]);
    $stmt2 = $db->prepare("DELETE FROM support_chat_rooms WHERE creator_id = ?");
    $stmt2->execute([$testUserId]);
    $stmt3 = $db->prepare("DELETE FROM support_chat_messages WHERE room_id LIKE 'test_%'");
    $stmt3->execute();
    echo "✅ 測試數據清理完成\n\n";
    
    // 確保測試管理員存在且有正確權限
    echo "👤 設置測試管理員...\n";
    $stmt = $db->prepare("INSERT INTO users (id, name, email, permission) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE permission = ?");
    $stmt->execute([$testAdminId, 'Test Admin', 'admin@test.com', 99, 99]);
    echo "✅ 測試管理員設置完成\n\n";
    
    // 測試 1: 建立客服事件
    echo "📝 測試 1: 建立客服事件\n";
    $result1 = createSupportIssue($testUserId, $testTitle, $testDescription);
    if ($result1['success']) {
        echo "✅ 客服事件建立成功\n";
        $roomId = $result1['data']['room_id'];
        echo "   聊天室 ID: $roomId\n";
    } else {
        echo "❌ 客服事件建立失敗: " . $result1['message'] . "\n";
        exit(1);
    }
    echo "\n";
    
    // 測試 2: 檢查初始狀態
    echo "📝 測試 2: 檢查初始狀態\n";
    $eventData = getSupportEventData($roomId);
    if ($eventData && $eventData['status'] === 'submitted' && $eventData['participant_id'] === null) {
        echo "✅ 初始狀態正確：status = submitted, participant_id = null\n";
    } else {
        echo "❌ 初始狀態不正確\n";
        var_dump($eventData);
        exit(1);
    }
    echo "\n";
    
    // 測試 3: 管理員接手
    echo "📝 測試 3: 管理員接手\n";
    $claimResult = adminClaimIssue($testAdminId, $roomId);
    if ($claimResult['success']) {
        echo "✅ 管理員接手成功\n";
        echo "   狀態變更: " . $claimResult['data']['old_status'] . " → " . $claimResult['data']['status'] . "\n";
    } else {
        echo "❌ 管理員接手失敗: " . $claimResult['message'] . "\n";
        exit(1);
    }
    echo "\n";
    
    // 測試 4: 檢查接手後狀態
    echo "📝 測試 4: 檢查接手後狀態\n";
    $eventDataAfter = getSupportEventData($roomId);
    if ($eventDataAfter && 
        $eventDataAfter['status'] === 'in_progress' && 
        $eventDataAfter['participant_id'] == $testAdminId) {
        echo "✅ 接手後狀態正確：status = in_progress, participant_id = $testAdminId\n";
    } else {
        echo "❌ 接手後狀態不正確\n";
        var_dump($eventDataAfter);
        exit(1);
    }
    echo "\n";
    
    // 測試 5: 檢查系統訊息
    echo "📝 測試 5: 檢查系統訊息\n";
    $systemMessages = getSystemMessages($roomId);
    $hasAdminJoinMessage = false;
    foreach ($systemMessages as $msg) {
        if (strpos($msg['content'], 'Admin has joined the chat') !== false) {
            $hasAdminJoinMessage = true;
            break;
        }
    }
    
    if ($hasAdminJoinMessage) {
        echo "✅ 系統訊息正確發送：Admin has joined the chat\n";
    } else {
        echo "❌ 系統訊息未正確發送\n";
        var_dump($systemMessages);
        exit(1);
    }
    echo "\n";
    
    // 清理測試數據
    echo "🧹 清理測試數據...\n";
    $stmt1 = $db->prepare("DELETE FROM support_events WHERE user_id = ?");
    $stmt1->execute([$testUserId]);
    $stmt2 = $db->prepare("DELETE FROM support_chat_rooms WHERE creator_id = ?");
    $stmt2->execute([$testUserId]);
    $stmt3 = $db->prepare("DELETE FROM support_chat_messages WHERE room_id = ?");
    $stmt3->execute([$roomId]);
    $stmt4 = $db->prepare("DELETE FROM users WHERE id = ?");
    $stmt4->execute([$testAdminId]);
    echo "✅ 測試數據清理完成\n\n";
    
    echo "🎉 所有測試通過！管理員接手流程功能正常\n";
    
} catch (Exception $e) {
    echo "❌ 測試失敗: " . $e->getMessage() . "\n";
    exit(1);
}

/**
 * 建立客服事件
 */
function createSupportIssue($userId, $title, $description) {
    try {
        $postData = json_encode([
            'title' => $title,
            'description' => $description
        ]);
        
        $context = stream_context_create([
            'http' => [
                'method' => 'POST',
                'header' => [
                    'Content-Type: application/json',
                    'Authorization: Bearer ' . generateTestToken($userId)
                ],
                'content' => $postData
            ]
        ]);
        
        $response = @file_get_contents('http://localhost:8888/here4help/backend/api/support/create_issue.php', false, $context);
        
        if ($response === false) {
            return ['success' => false, 'message' => 'API request failed'];
        }
        
        return json_decode($response, true);
        
    } catch (Exception $e) {
        return ['success' => false, 'message' => $e->getMessage()];
    }
}

/**
 * 管理員接手
 */
function adminClaimIssue($adminId, $roomId) {
    try {
        $postData = json_encode([
            'room_id' => $roomId
        ]);
        
        $context = stream_context_create([
            'http' => [
                'method' => 'POST',
                'header' => [
                    'Content-Type: application/json',
                    'Authorization: Bearer ' . generateTestToken($adminId, 99)
                ],
                'content' => $postData
            ]
        ]);
        
        $response = @file_get_contents('http://localhost:8888/here4help/backend/api/support/claim.php', false, $context);
        
        if ($response === false) {
            return ['success' => false, 'message' => 'API request failed'];
        }
        
        return json_decode($response, true);
        
    } catch (Exception $e) {
        return ['success' => false, 'message' => $e->getMessage()];
    }
}

/**
 * 獲取客服事件數據
 */
function getSupportEventData($roomId) {
    try {
        $db = Database::getInstance()->getConnection();
        
        $stmt = $db->prepare("
            SELECT scr.*, se.status, se.user_id, se.admin_id
            FROM support_chat_rooms scr
            LEFT JOIN support_events se ON scr.id = se.support_chat_room_id
            WHERE scr.id = ?
        ");
        $stmt->execute([$roomId]);
        
        return $stmt->fetch(PDO::FETCH_ASSOC);
        
    } catch (Exception $e) {
        return null;
    }
}

/**
 * 獲取系統訊息
 */
function getSystemMessages($roomId) {
    try {
        $db = Database::getInstance()->getConnection();
        
        $stmt = $db->prepare("
            SELECT * FROM support_chat_messages 
            WHERE room_id = ? AND kind = 'system'
            ORDER BY created_at DESC
        ");
        $stmt->execute([$roomId]);
        
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
        
    } catch (Exception $e) {
        return [];
    }
}

/**
 * 生成測試用 JWT Token
 */
function generateTestToken($userId, $permission = 1) {
    return base64_encode(json_encode([
        'user_id' => $userId,
        'email' => 'test@example.com',
        'name' => 'Test User',
        'permission' => $permission,
        'iat' => time(),
        'exp' => time() + 3600
    ]));
}
?>
