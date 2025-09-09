<?php
/**
 * 客服事件單一進行中限制測試
 * 
 * 測試項目：
 * 1. 用戶只能有一個進行中的客服事件
 * 2. 嘗試建立第二個事件時應該被拒絕
 * 3. 結案後可以建立新的事件
 */

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../utils/Response.php';

// 測試用戶 ID
$testUserId = 999;
$testTitle1 = 'Test Support Case 1';
$testTitle2 = 'Test Support Case 2';
$testDescription = 'This is a test support case description.';

echo "🧪 開始客服事件單一進行中限制測試\n";
echo "測試用戶 ID: $testUserId\n\n";

try {
    $db = Database::getInstance()->getConnection();
    
    // 清理測試數據
    echo "🧹 清理測試數據...\n";
    $stmt1 = $db->prepare("DELETE FROM support_events WHERE user_id = ?");
    $stmt1->execute([$testUserId]);
    $stmt2 = $db->prepare("DELETE FROM support_chat_rooms WHERE creator_id = ?");
    $stmt2->execute([$testUserId]);
    echo "✅ 測試數據清理完成\n\n";
    
    // 測試 1: 建立第一個客服事件
    echo "📝 測試 1: 建立第一個客服事件\n";
    $result1 = createSupportIssue($testUserId, $testTitle1, $testDescription);
    if ($result1['success']) {
        echo "✅ 第一個客服事件建立成功\n";
        $roomId1 = $result1['data']['room_id'];
        echo "   聊天室 ID: $roomId1\n";
    } else {
        echo "❌ 第一個客服事件建立失敗: " . $result1['message'] . "\n";
        exit(1);
    }
    echo "\n";
    
    // 測試 2: 嘗試建立第二個客服事件（應該失敗）
    echo "📝 測試 2: 嘗試建立第二個客服事件（應該失敗）\n";
    $result2 = createSupportIssue($testUserId, $testTitle2, $testDescription);
    if (!$result2['success']) {
        echo "✅ 第二個客服事件被正確拒絕\n";
        echo "   拒絕原因: " . $result2['message'] . "\n";
    } else {
        echo "❌ 第二個客服事件不應該被允許建立\n";
        exit(1);
    }
    echo "\n";
    
    // 測試 3: 結案第一個事件
    echo "📝 測試 3: 結案第一個事件\n";
    $resolveResult = resolveSupportIssue($roomId1, 5, 'Test review');
    if ($resolveResult['success']) {
        echo "✅ 第一個客服事件結案成功\n";
    } else {
        echo "❌ 客服事件結案失敗: " . $resolveResult['message'] . "\n";
        exit(1);
    }
    echo "\n";
    
    // 測試 4: 結案後建立新的客服事件（應該成功）
    echo "📝 測試 4: 結案後建立新的客服事件（應該成功）\n";
    $result3 = createSupportIssue($testUserId, $testTitle2, $testDescription);
    if ($result3['success']) {
        echo "✅ 結案後新的客服事件建立成功\n";
        $roomId2 = $result3['data']['room_id'];
        echo "   聊天室 ID: $roomId2\n";
    } else {
        echo "❌ 結案後新的客服事件建立失敗: " . $result3['message'] . "\n";
        exit(1);
    }
    echo "\n";
    
    // 清理測試數據
    echo "🧹 清理測試數據...\n";
    $stmt1 = $db->prepare("DELETE FROM support_events WHERE user_id = ?");
    $stmt1->execute([$testUserId]);
    $stmt2 = $db->prepare("DELETE FROM support_chat_rooms WHERE creator_id = ?");
    $stmt2->execute([$testUserId]);
    echo "✅ 測試數據清理完成\n\n";
    
    echo "🎉 所有測試通過！單一進行中事件限制功能正常\n";
    
} catch (Exception $e) {
    echo "❌ 測試失敗: " . $e->getMessage() . "\n";
    exit(1);
}

/**
 * 建立客服事件
 */
function createSupportIssue($userId, $title, $description) {
    try {
        // 模擬 API 請求
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
 * 結案客服事件
 */
function resolveSupportIssue($roomId, $rating, $review) {
    try {
        // 模擬 API 請求
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
                    'Authorization: Bearer ' . generateTestToken(999)
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
 * 生成測試用 JWT Token
 */
function generateTestToken($userId) {
    // 簡化的測試 token，實際應該使用正確的 JWT
    return base64_encode(json_encode([
        'user_id' => $userId,
        'email' => 'test@example.com',
        'name' => 'Test User',
        'permission' => 1,
        'iat' => time(),
        'exp' => time() + 3600
    ]));
}
?>
