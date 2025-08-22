<?php
/**
 * 客服事件管理 API
 * 
 * 支援的操作：
 * - POST: 新增事件（僅限客服管理員）
 * - GET: 查詢聊天室內事件列表
 * - PATCH: 更新事件狀態
 * 
 * 路徑：/api/support/events
 */

require_once '../../config/database.php';
require_once '../../utils/JWTManager.php';
require_once '../../utils/Response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PATCH, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    // JWT 認證
    $headers = getallheaders();
    $authHeader = $headers['Authorization'] ?? '';
    
    if (!$authHeader || !preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
        Response::error('Missing or invalid authorization header', 401);
    }
    
    $token = $matches[1];
    $jwtManager = new JWTManager();
    $payload = $jwtManager->validateToken($token);
    
    if (!$payload) {
        Response::error('Invalid or expired token', 401);
    }
    
    $userId = $payload['user_id'];
    $db = Database::getInstance()->getConnection();
    
    // 路由處理
    switch ($_SERVER['REQUEST_METHOD']) {
        case 'GET':
            handleGetEvents($db, $userId);
            break;
        case 'POST':
            handleCreateEvent($db, $userId);
            break;
        case 'PATCH':
            handleUpdateEvent($db, $userId);
            break;
        default:
            Response::error('Method not allowed', 405);
    }
    
} catch (Exception $e) {
    error_log('Support Events API Error: ' . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}

/**
 * 獲取聊天室內事件列表
 */
function handleGetEvents($db, $userId) {
    $chatRoomId = $_GET['chat_room_id'] ?? null;
    
    if (!$chatRoomId) {
        Response::error('chat_room_id parameter is required', 400);
    }
    
    // 驗證用戶是否有權限訪問此聊天室
    $roomStmt = $db->prepare("
        SELECT id, type, creator_id, participant_id 
        FROM chat_rooms 
        WHERE id = ? AND type = 'support'
    ");
    $roomStmt->execute([$chatRoomId]);
    $room = $roomStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$room) {
        Response::error('Support chat room not found', 404);
    }
    
    // 檢查用戶是否為聊天室參與者
    if ($room['creator_id'] != $userId && $room['participant_id'] != $userId) {
        Response::error('Access denied to this chat room', 403);
    }
    
    // 獲取事件列表
    $eventsStmt = $db->prepare("
        SELECT 
            se.id,
            se.title,
            se.description,
            se.status,
            se.closed_at,
            se.rating,
            se.review,
            se.created_at,
            se.updated_at,
            u.name as customer_name,
            a.full_name as admin_name
        FROM support_events se
        LEFT JOIN users u ON se.user_id = u.id
        LEFT JOIN admins a ON se.admin_id = a.id
        WHERE se.chat_room_id = ?
        ORDER BY se.created_at DESC
    ");
    $eventsStmt->execute([$chatRoomId]);
    $events = $eventsStmt->fetchAll(PDO::FETCH_ASSOC);
    
    // 為每個事件獲取歷程記錄
    foreach ($events as &$event) {
        $logsStmt = $db->prepare("
            SELECT 
                sel.old_status,
                sel.new_status,
                sel.created_at,
                a.full_name as admin_name
            FROM support_event_logs sel
            LEFT JOIN admins a ON sel.admin_id = a.id
            WHERE sel.event_id = ?
            ORDER BY sel.created_at ASC
        ");
        $logsStmt->execute([$event['id']]);
        $event['logs'] = $logsStmt->fetchAll(PDO::FETCH_ASSOC);
    }
    
    Response::success([
        'events' => $events,
        'chat_room_id' => $chatRoomId
    ]);
}

/**
 * 新增事件（僅限管理員）
 */
function handleCreateEvent($db, $userId) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        Response::error('Invalid JSON input', 400);
    }
    
    // 驗證必要欄位
    $chatRoomId = $input['chat_room_id'] ?? null;
    $title = trim($input['title'] ?? '');
    $description = trim($input['description'] ?? '');
    
    if (!$chatRoomId || empty($title)) {
        Response::error('chat_room_id and title are required', 400);
    }
    
    // 驗證聊天室是否為客服類型
    $roomStmt = $db->prepare("
        SELECT id, creator_id, participant_id 
        FROM chat_rooms 
        WHERE id = ? AND type = 'support'
    ");
    $roomStmt->execute([$chatRoomId]);
    $room = $roomStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$room) {
        Response::error('Support chat room not found', 404);
    }
    
    // 檢查用戶是否為管理員（這裡簡化處理，實際應該檢查 admins 表）
    // TODO: 實作完整的管理員權限檢查
    
    // 確定客戶 ID（非管理員的那一方）
    $customerId = ($room['creator_id'] == $userId) ? $room['participant_id'] : $room['creator_id'];
    
    try {
        $db->beginTransaction();
        
        // 插入事件記錄
        $insertStmt = $db->prepare("
            INSERT INTO support_events (
                chat_room_id, 
                user_id, 
                admin_id, 
                title, 
                description, 
                status,
                created_at,
                updated_at
            ) VALUES (?, ?, ?, ?, ?, 'open', NOW(), NOW())
        ");
        $insertStmt->execute([
            $chatRoomId,
            $customerId,
            $userId, // 假設當前用戶為管理員
            $title,
            $description
        ]);
        
        $eventId = $db->lastInsertId();
        
        // 記錄狀態變更日誌
        $logStmt = $db->prepare("
            INSERT INTO support_event_logs (
                event_id,
                admin_id,
                old_status,
                new_status,
                created_at
            ) VALUES (?, ?, NULL, 'open', NOW())
        ");
        $logStmt->execute([$eventId, $userId]);
        
        $db->commit();
        
        // 觸發 WebSocket 事件
        try {
            $socketUrl = 'http://localhost:3001/api/support-events/broadcast';
            $postData = json_encode([
                'type' => 'event_new',
                'chat_room_id' => $chatRoomId,
                'event_data' => [
                    'id' => $eventId,
                    'title' => $title,
                    'description' => $description,
                    'status' => 'open'
                ]
            ]);

            $context = stream_context_create([
                'http' => [
                    'method' => 'POST',
                    'header' => "Content-Type: application/json\r\n",
                    'content' => $postData,
                    'timeout' => 2 // 2秒超時，避免阻塞
                ]
            ]);

            // 非阻塞方式觸發（忽略結果）
            @file_get_contents($socketUrl, false, $context);
        } catch (Exception $e) {
            // WebSocket 觸發失敗不影響主要功能
            error_log("Support Events WebSocket trigger failed: " . $e->getMessage());
        }
        
        Response::success([
            'event_id' => $eventId,
            'message' => 'Event created successfully'
        ]);
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
}

/**
 * 更新事件狀態
 */
function handleUpdateEvent($db, $userId) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        Response::error('Invalid JSON input', 400);
    }
    
    $eventId = $input['event_id'] ?? null;
    $newStatus = $input['status'] ?? null;
    
    if (!$eventId || !$newStatus) {
        Response::error('event_id and status are required', 400);
    }
    
    // 驗證狀態值
    $validStatuses = ['open', 'in_progress', 'resolved', 'closed_by_customer'];
    if (!in_array($newStatus, $validStatuses)) {
        Response::error('Invalid status. Must be one of: ' . implode(', ', $validStatuses), 400);
    }
    
    // 獲取現有事件
    $eventStmt = $db->prepare("
        SELECT se.*, cr.creator_id, cr.participant_id
        FROM support_events se
        JOIN chat_rooms cr ON se.chat_room_id = cr.id
        WHERE se.id = ?
    ");
    $eventStmt->execute([$eventId]);
    $event = $eventStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$event) {
        Response::error('Event not found', 404);
    }
    
    // 權限檢查：客戶只能將狀態改為 closed_by_customer
    $isCustomer = ($event['user_id'] == $userId);
    $isParticipant = ($event['creator_id'] == $userId || $event['participant_id'] == $userId);
    
    if (!$isParticipant) {
        Response::error('Access denied to this event', 403);
    }
    
    if ($isCustomer && $newStatus !== 'closed_by_customer') {
        Response::error('Customers can only close events', 403);
    }
    
    try {
        $db->beginTransaction();
        
        $oldStatus = $event['status'];
        
        // 更新事件狀態
        $updateData = ['status' => $newStatus, 'updated_at' => date('Y-m-d H:i:s')];
        
        if ($newStatus === 'closed_by_customer') {
            $updateData['closed_at'] = date('Y-m-d H:i:s');
        }
        
        $updateStmt = $db->prepare("
            UPDATE support_events 
            SET status = ?, updated_at = ?" . 
            ($newStatus === 'closed_by_customer' ? ', closed_at = ?' : '') . "
            WHERE id = ?
        ");
        
        $params = [$newStatus, $updateData['updated_at']];
        if ($newStatus === 'closed_by_customer') {
            $params[] = $updateData['closed_at'];
        }
        $params[] = $eventId;
        
        $updateStmt->execute($params);
        
        // 記錄狀態變更日誌
        $logStmt = $db->prepare("
            INSERT INTO support_event_logs (
                event_id,
                admin_id,
                old_status,
                new_status,
                created_at
            ) VALUES (?, ?, ?, ?, NOW())
        ");
        $logStmt->execute([
            $eventId,
            $isCustomer ? null : $userId, // 客戶操作時 admin_id 為 null
            $oldStatus,
            $newStatus
        ]);
        
        $db->commit();
        
        Response::success([
            'event_id' => $eventId,
            'old_status' => $oldStatus,
            'new_status' => $newStatus,
            'message' => 'Event status updated successfully'
        ]);
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
}
