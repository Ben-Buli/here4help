<?php
/**
 * 客戶評分結案測試
 * 
 * 測試項目：
 * 1. 客戶可以對 in_progress 狀態的事件進行評分結案
 * 2. 評分後狀態變為 resolved
 * 3. 評分和評論正確保存
 * 4. 事件日誌正確記錄
 */

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../utils/Response.php';

// 測試用戶 ID
$testUserId = 996;
$testAdminId = 995;
$testTitle = 'Test Customer Rating Flow';
$testDescription = 'This is a test for customer rating flow.';
$testRating = 4;
$testReview = 'Great support service!';

echo "🧪 開始客戶評分結案測試\n";
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
    echo "✅ 測試數據清理完成\n\n";
    
    // 設置測試管理員
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
    
    // 測試 2: 管理員接手（設置為 in_progress 狀態）
    echo "📝 測試 2: 管理員接手\n";
    $claimResult = adminClaimIssue($testAdminId, $roomId);
    if ($claimResult['success']) {
        echo "✅ 管理員接手成功\n";
    } else {
        echo "❌ 管理員接手失敗: " . $claimResult['message'] . "\n";
        exit(1);
    }
    echo "\n";
    
    // 測試 3: 檢查 in_progress 狀態
    echo "📝 測試 3: 檢查 in_progress 狀態\n";
    $eventData = getSupportEventData($roomId);
    if ($eventData && $eventData['status'] === 'in_progress') {
        echo "✅ 狀態正確：status = in_progress\n";
    } else {
        echo "❌ 狀態不正確\n";
        var_dump($eventData);
        exit(1);
    }
    echo "\n";
    
    // 測試 4: 客戶評分結案
    echo "📝 測試 4: 客戶評分結案\n";
    $ratingResult = customerRateAndResolve($testUserId, $roomId, $testRating, $testReview);
    if ($ratingResult['success']) {
        echo "✅ 客戶評分結案成功\n";
        echo "   評分: {$testRating}/5\n";
        echo "   評論: $testReview\n";
    } else {
        echo "❌ 客戶評分結案失敗: " . $ratingResult['message'] . "\n";
        exit(1);
    }
    echo "\n";
    
    // 測試 5: 檢查結案後狀態
    echo "📝 測試 5: 檢查結案後狀態\n";
    $eventDataAfter = getSupportEventData($roomId);
    if ($eventDataAfter && 
        $eventDataAfter['status'] === 'resolved' && 
        $eventDataAfter['rating'] == $testRating &&
        $eventDataAfter['review'] === $testReview) {
        echo "✅ 結案後狀態正確：\n";
        echo "   status = resolved\n";
        echo "   rating = {$eventDataAfter['rating']}\n";
        echo "   review = {$eventDataAfter['review']}\n";
    } else {
        echo "❌ 結案後狀態不正確\n";
        var_dump($eventDataAfter);
        exit(1);
    }
    echo "\n";
    
    // 測試 6: 檢查事件日誌
    echo "📝 測試 6: 檢查事件日誌\n";
    $eventLogs = getSupportEventLogs($eventDataAfter['event_id']);
    $hasResolvedLog = false;
    foreach ($eventLogs as $log) {
        if ($log['new_status'] === 'resolved') {
            $hasResolvedLog = true;
            echo "✅ 找到結案日誌記錄\n";
            echo "   狀態變更: {$log['old_status']} → {$log['new_status']}\n";
            echo "   時間: {$log['created_at']}\n";
            break;
        }
    }
    
    if (!$hasResolvedLog) {
        echo "❌ 未找到結案日誌記錄\n";
        var_dump($eventLogs);
        exit(1);
    }
    echo "\n";
    
    // 清理測試數據
    echo "🧹 清理測試數據...\n";
    $stmt1 = $db->prepare("DELETE FROM support_events WHERE user_id = ?");
    $stmt1->execute([$testUserId]);
    $stmt2 = $db->prepare("DELETE FROM support_chat_rooms WHERE creator_id = ?");
    $stmt2->execute([$testUserId]);
    $stmt3 = $db->prepare("DELETE FROM users WHERE id = ?");
    $stmt3->execute([$testAdminId]);
    echo "✅ 測試數據清理完成\n\n";
    
    echo "🎉 所有測試通過！客戶評分結案功能正常\n";
    
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
 * 客戶評分結案
 */
function customerRateAndResolve($userId, $roomId, $rating, $review) {
    try {
        $postData = json_encode([
            'room_id' => $roomId,
            'rating' => $rating,
            'review' => $review
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
        
        $response = @file_get_contents('http://localhost:8888/here4help/backend/api/support/resolve.php', false, $context);
        
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
            SELECT scr.*, se.*
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
 * 獲取事件日誌
 */
function getSupportEventLogs($eventId) {
    try {
        $db = Database::getInstance()->getConnection();
        
        $stmt = $db->prepare("
            SELECT * FROM support_event_logs 
            WHERE event_id = ?
            ORDER BY created_at ASC
        ");
        $stmt->execute([$eventId]);
        
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
