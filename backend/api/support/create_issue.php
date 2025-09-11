<?php
/**
 * 整合建立客服事件 API
 * 
 * 功能：
 * - 檢查使用者同時開啟事件數量限制（只允許1個 submitted/in_progress）
 * - 建立新的 support_chat_rooms(type='support', participant_id=NULL)
 * - 建立 support_events(status='submitted')
 * - 建立 support_event_logs
 * - 插入系統訊息 support_chat_messages(kind='system')
 * - 回傳 room_id, event_id
 * 
 * 路徑：POST /api/support/create_issue.php
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
    
    $userId = $payload['user_id'];
    $db = Database::getInstance()->getConnection();
    
    // 解析請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        Response::error('Invalid JSON input', 400);
    }
    
    // 驗證必要欄位
    $title = trim($input['title'] ?? '');
    $description = trim($input['description'] ?? '');
    
    if (empty($title)) {
        Response::error('Title is required', 400);
    }
    
    if (empty($description)) {
        Response::error('Description is required', 400);
    }
    
    // 檢查使用者同時開啟的客服事件數量限制（改為只允許1個進行中事件）
    $activeCountStmt = $db->prepare("
        SELECT COUNT(*) as active_count
        FROM support_events se
        JOIN support_chat_rooms scr ON scr.id = se.support_chat_room_id AND scr.type = 'support'
        WHERE se.user_id = ? AND se.status IN ('submitted', 'in_progress')
    ");
    $activeCountStmt->execute([$userId]);
    $activeCount = $activeCountStmt->fetch(PDO::FETCH_ASSOC)['active_count'];
    
    if ($activeCount >= 1) {
        Response::error('You already have an active support case. Please resolve the existing case before creating a new one.', 422);
    }
    
    // 開始資料庫事務
    $db->beginTransaction();
    
    try {
        // 1. 建立新的支援聊天室（每次建立新事件都創建新聊天室）
        // admin_id 初始為 NULL，等待管理員接手
        $createRoomStmt = $db->prepare("
            INSERT INTO support_chat_rooms (type, user_id, admin_id, created_at)
            VALUES ('support', ?, NULL, NOW())
        ");
        $createRoomStmt->execute([$userId]);
        $roomId = $db->lastInsertId();
        
        // 2. 建立客服事件
        $createEventStmt = $db->prepare("
            INSERT INTO support_events (
                support_chat_room_id, user_id, admin_id, title, description, 
                status, created_at, updated_at
            ) VALUES (?, ?, NULL, ?, ?, 'submitted', NOW(), NOW())
        ");
        $createEventStmt->execute([$roomId, $userId, $title, $description]);
        $eventId = $db->lastInsertId();
        
        // 3. 建立事件日誌
        $createLogStmt = $db->prepare("
            INSERT INTO support_event_logs (
                event_id, admin_id, old_status, new_status, created_at
            ) VALUES (?, NULL, NULL, 'submitted', NOW())
        ");
        $createLogStmt->execute([$eventId]);
        
        // 4. 插入系統訊息
        $systemMessage = "Support case created: {$title}. Please wait for admin assistance.";
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
            $socketUrl = 'http://localhost:3001/support/event/new';
            $socketData = [
                'chatRoomId' => $roomId,
                'eventData' => [
                    'id' => $eventId,
                    'title' => $title,
                    'description' => $description,
                    'status' => 'submitted',
                    'user_id' => $userId
                ]
            ];
            
            // 非阻塞式 Socket 通知
            $context = stream_context_create([
                'http' => [
                    'method' => 'POST',
                    'header' => 'Content-Type: application/json',
                    'content' => json_encode($socketData),
                    'timeout' => 1 // 1秒超時，避免阻塞
                ]
            ]);
            
            @file_get_contents($socketUrl, false, $context);
        } catch (Exception $e) {
            // Socket 通知失敗不影響主要功能
            error_log("Support Event Socket notification failed: " . $e->getMessage());
        }
        
        // 回傳成功結果
        Response::success([
            'room_id' => (string)$roomId,
            'event_id' => (string)$eventId,
            'title' => $title,
            'description' => $description,
            'status' => 'submitted',
            'message' => 'Support case created successfully'
        ]);
        
    } catch (Exception $e) {
        // 回滾事務
        $db->rollBack();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log('Create Support Issue API Error: ' . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}
?>
