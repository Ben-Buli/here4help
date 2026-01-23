<?php
require_once __DIR__ . '/bootstrap.php';
// 載入 PHP 8.4 相容性配置

/**
 * 客戶評分結案 API
 * 
 * 功能：
 * - 驗證客戶身份和事件擁有權
 * - 更新 support_events: rating, review, status='resolved', closed_at
 * - 新增事件日誌
 * - 插入系統訊息通知管理員
 * 
 * 路徑：POST /api/support/resolve.php
 */

require_once __DIR__ . '/../../config/database.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// 僅允許 POST 請求
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
}

try {
    // JWT 認證 - 支援 Header 和 URL 參數
    $headers = getallheaders();
    $authHeader = $headers['Authorization'] ?? '';
    $token = null;
    
    if ($authHeader && preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
        $token = $matches[1];
    } elseif (isset($_GET['token'])) {
        $token = $_GET['token'];
    }
    
    if (!$token) {
        Response::error('Missing or invalid authorization header', 401);
    }
    $jwtManager = new JWTManager();
    $payload = $jwtManager->validateToken($token);
    
    if (!$payload) {
        Response::error('Invalid or expired token', 401);
    }
    
    $userId = $payload['user_id'];
    $db = Database::getInstance()->getConnection();
    
    // 解析請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        Response::error('Invalid JSON input', 400);
    }
    
    // 驗證必要欄位
    $eventId = $input['event_id'] ?? '';
    $rating = $input['rating'] ?? null;
    $review = trim($input['review'] ?? '');
    
    if (empty($eventId)) {
        Response::error('event_id is required', 400);
    }
    
    if ($rating === null || !is_numeric($rating) || $rating < 1 || $rating > 5) {
        Response::error('rating must be a number between 1 and 5', 400);
    }
    
    $rating = (int)$rating;
    
    // 開始資料庫事務
    $db->beginTransaction();
    
    try {
        // 1. 驗證事件存在且屬於該用戶
        $eventStmt = $db->prepare("
            SELECT se.id, se.support_chat_room_id, se.user_id, se.admin_id, se.status, se.title,
                   scr.id as room_id, scr.user_id, scr.admin_id
            FROM support_events se
            JOIN support_chat_rooms scr ON scr.id = se.support_chat_room_id
            WHERE se.id = ? AND se.user_id = ?
        ");
        $eventStmt->execute([$eventId, $userId]);
        $event = $eventStmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$event) {
            Response::error('Support event not found or access denied', 404);
        }
        
        // 2. 檢查事件狀態
        if ($event['status'] === 'resolved') {
            Response::error('This support case has already been resolved', 400);
        }
        
        if ($event['status'] === 'submitted') {
            Response::error('Cannot resolve a support case that has not been handled by an admin yet', 400);
        }
        
        $roomId = $event['room_id'];
        $oldStatus = $event['status'];
        
        // 3. 更新事件：設定評分、評論、狀態和結案時間
        $updateEventStmt = $db->prepare("
            UPDATE support_events 
            SET rating = ?, review = ?, status = 'resolved', closed_at = NOW(), updated_at = NOW()
            WHERE id = ?
        ");
        $updateEventStmt->execute([$rating, $review, $eventId]);
        
        // 4. 新增事件日誌
        $createLogStmt = $db->prepare("
            INSERT INTO support_event_logs (
                event_id, admin_id, old_status, new_status, created_at
            ) VALUES (?, NULL, ?, 'resolved', NOW())
        ");
        $createLogStmt->execute([$eventId, $oldStatus]);
        
        // 5. 插入系統訊息通知管理員
        $systemMessage = "Customer has resolved this support case with a {$rating}-star rating.";
        if (!empty($review)) {
            $systemMessage .= " Review: " . $review;
        }
        
        $createMessageStmt = $db->prepare("
            INSERT INTO support_chat_messages (
                room_id, user_id, admin_id, content, kind, role, created_at
            ) VALUES (?, NULL, 1, ?, 'system', 'admin', NOW())
        ");
        $createMessageStmt->execute([$roomId, $systemMessage]);
        
        // 提交事務
        $db->commit();
        
        // 觸發 Socket 事件通知
        try {
            $socketUrl = ($_ENV['SOCKET_SERVER_URL'] ?? 'https://hero4help.demofhs.com/socket') . '/support/event/resolve';
            $socketData = [
                'chatRoomId' => $roomId,
                'eventId' => $eventId,
                'oldStatus' => $oldStatus,
                'newStatus' => 'resolved',
                'rating' => $rating,
                'review' => $review,
                'userId' => $userId
            ];
            
            // 非阻塞式 Socket 通知
            $context = stream_context_create([
                'http' => [
                    'method' => 'POST',
                    'header' => 'Content-Type: application/json',
                    'content' => json_encode($socketData),
                    'timeout' => 1
                ]
            ]);
            
            @file_get_contents($socketUrl, false, $context);
        } catch (Exception $e) {
            error_log("Support Event Socket notification failed: " . $e->getMessage());
        }
        
        // 回傳成功結果
        Response::success([
            'event_id' => (string)$eventId,
            'room_id' => (string)$roomId,
            'rating' => $rating,
            'review' => $review,
            'status' => 'resolved',
            'old_status' => $oldStatus,
            'message' => 'Support case resolved successfully'
        ]);
        
    } catch (Exception $e) {
        // 回滾事務
        $db->rollBack();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log('Resolve Support Issue API Error: ' . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}
?>
