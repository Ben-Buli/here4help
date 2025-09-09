<?php
/**
 * 管理員接手客服事件 API
 * 
 * 功能：
 * - 檢查房間是否已被接手
 * - 更新最新事件：admin_id, status='in_progress'
 * - 更新聊天室：participant_id=adminId
 * - 新增事件日誌
 * 
 * 路徑：POST /api/support/claim.php
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';

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
    
    $adminId = $payload['user_id'];
    $db = Database::getInstance()->getConnection();
    
    // 檢查管理員權限 (users.permission = 99)
    $adminCheckStmt = $db->prepare("
        SELECT permission FROM users WHERE id = ?
    ");
    $adminCheckStmt->execute([$adminId]);
    $adminUser = $adminCheckStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$adminUser || $adminUser['permission'] != 99) {
        Response::error('Access denied. Admin privileges required.', 403);
    }
    
    // 解析請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        Response::error('Invalid JSON input', 400);
    }
    
    // 驗證必要欄位
    $roomId = $input['room_id'] ?? '';
    
    if (empty($roomId)) {
        Response::error('room_id is required', 400);
    }
    
    // 開始資料庫事務
    $db->beginTransaction();
    
    try {
        // 1. 驗證聊天室存在且為支援類型
        $roomStmt = $db->prepare("
            SELECT id, type, user_id, admin_id 
            FROM support_chat_rooms 
            WHERE id = ? AND type = 'support'
        ");
        $roomStmt->execute([$roomId]);
        $room = $roomStmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$room) {
            Response::error('Support chat room not found', 404);
        }
        
        // 2. 檢查是否已被其他管理員接手
        if (!empty($room['admin_id']) && $room['admin_id'] != $adminId) {
            Response::error('This support case has already been claimed by another admin', 409);
        }
        
        // 3. 獲取該聊天室的最新事件
        $latestEventStmt = $db->prepare("
            SELECT id, status, user_id, admin_id
            FROM support_events 
            WHERE support_chat_room_id = ?
            ORDER BY created_at DESC
            LIMIT 1
        ");
        $latestEventStmt->execute([$roomId]);
        $latestEvent = $latestEventStmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$latestEvent) {
            Response::error('No support event found for this room', 404);
        }
        
        // 4. 檢查事件是否已結案
        if ($latestEvent['status'] === 'resolved') {
            Response::error('Cannot claim a resolved support case', 400);
        }
        
        // 5. 檢查是否已被同一管理員接手
        if ($latestEvent['admin_id'] == $adminId && $latestEvent['status'] === 'in_progress') {
            Response::error('You have already claimed this support case', 400);
        }
        
        $eventId = $latestEvent['id'];
        $oldStatus = $latestEvent['status'];
        
        // 6. 更新事件：設定管理員ID和狀態
        $updateEventStmt = $db->prepare("
            UPDATE support_events 
            SET admin_id = ?, status = 'in_progress', updated_at = NOW()
            WHERE id = ?
        ");
        $updateEventStmt->execute([$adminId, $eventId]);
        
        // 7. 更新聊天室：設定參與者為管理員（從 NULL 更新為管理員 ID）
        $updateRoomStmt = $db->prepare("
            UPDATE support_chat_rooms 
            SET admin_id = ?
            WHERE id = ?
        ");
        $updateRoomStmt->execute([$adminId, $roomId]);
        
        // 8. 新增事件日誌
        $createLogStmt = $db->prepare("
            INSERT INTO support_event_logs (
                event_id, admin_id, old_status, new_status, created_at
            ) VALUES (?, ?, ?, 'in_progress', NOW())
        ");
        $createLogStmt->execute([$eventId, $adminId, $oldStatus]);
        
        // 9. 插入系統訊息通知客戶
        $systemMessage = "Admin has joined the chat and is now handling your support case.";
        $createMessageStmt = $db->prepare("
            INSERT INTO support_chat_messages (
                room_id, from_user_id, content, kind, created_at
            ) VALUES (?, ?, ?, 'system', NOW())
        ");
        $createMessageStmt->execute([$roomId, $adminId, $systemMessage]);
        
        // 提交事務
        $db->commit();
        
        // 觸發 Socket 事件通知
        try {
            $socketUrl = 'http://localhost:3001/support/event/update';
            $socketData = [
                'chatRoomId' => $roomId,
                'eventId' => $eventId,
                'oldStatus' => $oldStatus,
                'newStatus' => 'in_progress',
                'adminId' => $adminId
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
            'room_id' => (string)$roomId,
            'event_id' => (string)$eventId,
            'admin_id' => (string)$adminId,
            'status' => 'in_progress',
            'old_status' => $oldStatus,
            'message' => 'Support case claimed successfully'
        ]);
        
    } catch (Exception $e) {
        // 回滾事務
        $db->rollBack();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log('Claim Support Issue API Error: ' . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}
?>
