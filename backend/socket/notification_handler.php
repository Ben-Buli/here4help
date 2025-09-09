<?php
/**
 * Socket.IO 通知處理器
 * 用於接收後端發送的狀態更新通知並轉發給相關用戶
 */

require_once __DIR__ . '/../config/env_loader.php';

// 確保環境變數已載入
EnvLoader::load();

// 設置 CORS
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

try {
    // 驗證請求
    $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    $expectedToken = $_ENV['SOCKET_SERVER_TOKEN'] ?? 'your-socket-server-token';
    
    if (empty($authHeader) || !preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
        throw new Exception('Authorization header required');
    }
    
    $token = $matches[1];
    if ($token !== $expectedToken) {
        throw new Exception('Invalid token');
    }
    
    // 解析請求數據
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        throw new Exception('Invalid JSON data');
    }
    
    $event = $input['event'] ?? '';
    $data = $input['data'] ?? [];
    $userIds = $input['userIds'] ?? [];
    
    if (empty($event)) {
        throw new Exception('Event is required');
    }
    
    // 記錄通知
    error_log("[SocketNotifier] Received notification: $event for users: " . implode(',', $userIds));
    
    // 處理不同類型的事件
    $success = false;
    switch ($event) {
        case 'support_event_created':
            $success = handleSupportEventCreated($data);
            break;
        case 'support_event_updated':
            $success = handleSupportEventUpdated($data);
            break;
        case 'support_event_closed':
            $success = handleSupportEventClosed($data);
            break;
        case 'support_message_new':
            $success = handleSupportMessageNew($data);
            break;
        default:
            // 其他事件的默認處理
            $success = handleGenericEvent($event, $data, $userIds);
            break;
    }
    
    $response = [
        'success' => $success,
        'event' => $event,
        'userIds' => $userIds,
        'timestamp' => date('Y-m-d H:i:s')
    ];
    
    http_response_code(200);
    echo json_encode($response);
    
} catch (Exception $e) {
    error_log("[SocketNotifier] Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => $e->getMessage()]);
}

/**
 * 處理客服事件建立通知
 */
function handleSupportEventCreated($data) {
    try {
        $chatRoomId = $data['chat_room_id'] ?? null;
        $eventData = $data['event'] ?? [];
        
        if (!$chatRoomId) {
            error_log("[SocketNotifier] Support event created: missing chat_room_id");
            return false;
        }
        
        // 發送 HTTP 請求到 Socket.IO 服務器
        return sendToSocketServer('support_event_new', [
            'chatRoomId' => $chatRoomId,
            'eventData' => $eventData
        ]);
        
    } catch (Exception $e) {
        error_log("[SocketNotifier] Support event created error: " . $e->getMessage());
        return false;
    }
}

/**
 * 處理客服事件更新通知
 */
function handleSupportEventUpdated($data) {
    try {
        $chatRoomId = $data['chat_room_id'] ?? null;
        $eventId = $data['event_id'] ?? null;
        $oldStatus = $data['old_status'] ?? null;
        $newStatus = $data['new_status'] ?? null;
        $adminId = $data['admin_id'] ?? null;
        
        if (!$chatRoomId || !$eventId) {
            error_log("[SocketNotifier] Support event updated: missing required data");
            return false;
        }
        
        // 發送 HTTP 請求到 Socket.IO 服務器
        return sendToSocketServer('support_event_update', [
            'chatRoomId' => $chatRoomId,
            'eventId' => $eventId,
            'oldStatus' => $oldStatus,
            'newStatus' => $newStatus,
            'adminId' => $adminId
        ]);
        
    } catch (Exception $e) {
        error_log("[SocketNotifier] Support event updated error: " . $e->getMessage());
        return false;
    }
}

/**
 * 處理客服事件結案通知
 */
function handleSupportEventClosed($data) {
    try {
        $chatRoomId = $data['chat_room_id'] ?? null;
        $eventId = $data['event_id'] ?? null;
        $rating = $data['rating'] ?? null;
        $review = $data['review'] ?? null;
        
        if (!$chatRoomId || !$eventId) {
            error_log("[SocketNotifier] Support event closed: missing required data");
            return false;
        }
        
        // 發送 HTTP 請求到 Socket.IO 服務器
        return sendToSocketServer('support_event_closed', [
            'chatRoomId' => $chatRoomId,
            'eventId' => $eventId,
            'rating' => $rating,
            'review' => $review
        ]);
        
    } catch (Exception $e) {
        error_log("[SocketNotifier] Support event closed error: " . $e->getMessage());
        return false;
    }
}

/**
 * 處理客服訊息通知
 */
function handleSupportMessageNew($data) {
    try {
        $chatRoomId = $data['chat_room_id'] ?? null;
        $messageData = $data['message'] ?? [];
        
        if (!$chatRoomId) {
            error_log("[SocketNotifier] Support message new: missing chat_room_id");
            return false;
        }
        
        // 客服訊息使用一般的訊息通知機制
        return handleGenericEvent('message', $data, []);
        
    } catch (Exception $e) {
        error_log("[SocketNotifier] Support message new error: " . $e->getMessage());
        return false;
    }
}

/**
 * 處理一般事件
 */
function handleGenericEvent($event, $data, $userIds) {
    try {
        // 特殊處理訊息事件
        if ($event === 'message') {
            return handleMessageEvent($data, $userIds);
        }
        
        // 其他事件的默認處理
        error_log("[SocketNotifier] Generic event handled: $event");
        return true;
        
    } catch (Exception $e) {
        error_log("[SocketNotifier] Generic event error: " . $e->getMessage());
        return false;
    }
}

/**
 * 處理訊息事件
 */
function handleMessageEvent($data, $userIds) {
    try {
        $roomId = $data['room_id'] ?? null;
        $messageId = $data['message_id'] ?? null;
        $kind = $data['kind'] ?? 'text';
        
        if (!$roomId || !$messageId) {
            error_log("[SocketNotifier] Message event: missing room_id or message_id");
            return false;
        }
        
        // 記錄訊息事件
        error_log("[SocketNotifier] Processing message event: room_id=$roomId, message_id=$messageId, kind=$kind");
        
        // 發送到 Socket.IO 服務器
        return sendToSocketServer('message', $data);
        
    } catch (Exception $e) {
        error_log("[SocketNotifier] Message event error: " . $e->getMessage());
        return false;
    }
}

/**
 * 發送請求到 Socket.IO 服務器
 */
function sendToSocketServer($event, $data) {
    try {
        $socketServerUrl = $_ENV['SOCKET_SERVER_URL'] ?? 'http://localhost:3001';
        $socketServerToken = $_ENV['SOCKET_SERVER_TOKEN'] ?? 'your-socket-server-token';
        
        $postData = json_encode([
            'event' => $event,
            'data' => $data,
            'timestamp' => date('c')
        ]);
        
        $context = stream_context_create([
            'http' => [
                'method' => 'POST',
                'header' => [
                    'Content-Type: application/json',
                    'Authorization: Bearer ' . $socketServerToken
                ],
                'content' => $postData,
                'timeout' => 5
            ]
        ]);
        
        $result = @file_get_contents($socketServerUrl . '/api/notify', false, $context);
        
        if ($result === false) {
            error_log("[SocketNotifier] Failed to send to Socket.IO server: $event");
            return false;
        }
        
        error_log("[SocketNotifier] Successfully sent to Socket.IO server: $event");
        return true;
        
    } catch (Exception $e) {
        error_log("[SocketNotifier] Socket server communication error: " . $e->getMessage());
        return false;
    }
}
?>
