<?php
/**
 * 獲取客服聊天室列表 API
 * 
 * 功能：
 * - 支援用戶端：獲取自己的客服聊天室
 * - 支援管理員端：獲取自己負責的客服聊天室
 * - 包含最新訊息和未讀數統計
 * 
 * 路徑：GET /api/support/get_support_chat_list.php
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// 僅允許 GET 請求
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
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
    error_log('Get Support Chat List API: user_id: ' . $userId);
    $db = Database::getInstance()->getConnection();
    
    // 檢查用戶權限
    $userStmt = $db->prepare("SELECT permission FROM users WHERE id = ?");
    $userStmt->execute([$userId]);
    $user = $userStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        Response::error('User not found', 404);
    }
    
    // 檢查請求參數，決定查詢類型
    $viewType = $_GET['view_type'] ?? 'customer'; // 默認為客戶視角
    $isAdmin = ($user['permission'] == 99);
    
    // 根據視圖類型構建不同的查詢
    // 'admin' = 管理員後台視角（查看接手的聊天室）
    // 'customer' = 客戶視角（查看自己創建的聊天室，即使是管理員用戶）
    if ($isAdmin && $viewType === 'admin') {
        // 管理員後台視角：獲取自己接手的聊天室
        $chatListStmt = $db->prepare("
            SELECT 
                scr.id as room_id,
                scr.user_id,
                scr.admin_id,
                scr.created_at as room_created_at,
                u.name as customer_name,
                u.avatar_url as customer_avatar,
                se.id as event_id,
                se.title as event_title,
                se.status as event_status,
                se.rating,
                se.review,
                se.created_at as event_created_at,
                se.updated_at as event_updated_at,
                se.closed_at,
                (SELECT content FROM support_chat_messages 
                 WHERE room_id = scr.id 
                 ORDER BY created_at DESC LIMIT 1) as last_message,
                (SELECT created_at FROM support_chat_messages 
                 WHERE room_id = scr.id 
                 ORDER BY created_at DESC LIMIT 1) as last_message_time,
                (SELECT COUNT(*) FROM support_chat_messages scm
                 LEFT JOIN support_chat_reads scr_read ON scr_read.room_id = scm.room_id AND scr_read.admin_id = ? AND scr_read.role = 'admin'
                 WHERE scm.room_id = scr.id 
                 AND scm.role = 'user'
                 AND (scr_read.last_read_message_id IS NULL OR scm.id > scr_read.last_read_message_id)) as unread_count
            FROM support_chat_rooms scr
            JOIN users u ON u.id = scr.user_id
            LEFT JOIN support_events se ON se.support_chat_room_id = scr.id
            WHERE scr.type = 'support' AND scr.admin_id = ?
            ORDER BY 
                CASE WHEN se.status = 'in_progress' THEN 1
                     WHEN se.status = 'submitted' THEN 2
                     WHEN se.status = 'resolved' THEN 3
                     ELSE 4 END,
                se.updated_at DESC
        ");
        $chatListStmt->execute([$userId, $userId, $userId]);
        
    } else {
        // 客戶視角：獲取自己創建的客服聊天室（包括管理員作為客戶時）
        $chatListStmt = $db->prepare("
            SELECT 
                scr.id as room_id,
                scr.user_id,
                scr.admin_id,
                scr.created_at as room_created_at,
                admin_u.name as admin_name,
                admin_u.avatar_url as admin_avatar,
                se.id as event_id,
                se.title as event_title,
                se.status as event_status,
                se.rating,
                se.review,
                se.created_at as event_created_at,
                se.updated_at as event_updated_at,
                se.closed_at,
                (SELECT content FROM support_chat_messages 
                 WHERE room_id = scr.id 
                 ORDER BY created_at DESC LIMIT 1) as last_message,
                (SELECT created_at FROM support_chat_messages 
                 WHERE room_id = scr.id 
                 ORDER BY created_at DESC LIMIT 1) as last_message_time,
                (SELECT COUNT(*) FROM support_chat_messages scm
                 LEFT JOIN support_chat_reads scr_read ON scr_read.room_id = scm.room_id AND scr_read.user_id = ?
                 WHERE scm.room_id = scr.id 
                 AND scm.from_user_id != ?
                 AND (scr_read.last_read_message_id IS NULL OR scm.id > scr_read.last_read_message_id)) as unread_count
            FROM support_chat_rooms scr
            LEFT JOIN users admin_u ON admin_u.id = scr.admin_id
            LEFT JOIN support_events se ON se.support_chat_room_id = scr.id
            WHERE scr.type = 'support' AND scr.user_id = ?
            ORDER BY 
                CASE WHEN se.status = 'in_progress' THEN 1
                     WHEN se.status = 'submitted' THEN 2
                     WHEN se.status = 'resolved' THEN 3
                     ELSE 4 END,
                se.updated_at DESC
        ");
        $chatListStmt->execute([$userId, $userId, $userId]);
    }
    
    $chatList = $chatListStmt->fetchAll(PDO::FETCH_ASSOC);
    
    // 格式化結果
    $formattedList = [];
    foreach ($chatList as $chat) {
        $formattedChat = [
            'room_id' => (string)$chat['room_id'],
            'event_id' => $chat['event_id'] ? (string)$chat['event_id'] : null,
            'event_title' => $chat['event_title'],
            'event_status' => $chat['event_status'],
            'event_created_at' => $chat['event_created_at'],
            'event_updated_at' => $chat['event_updated_at'],
            'closed_at' => $chat['closed_at'],
            'rating' => $chat['rating'] ? (int)$chat['rating'] : null,
            'review' => $chat['review'],
            'last_message' => $chat['last_message'],
            'last_message_time' => $chat['last_message_time'],
            'unread_count' => (int)$chat['unread_count'],
            'room_created_at' => $chat['room_created_at']
        ];
        
        if ($isAdmin && $viewType === 'admin') {
            // 管理員後台視角：看到客戶資訊
            $formattedChat['customer'] = [
                'id' => (string)$chat['user_id'],
                'name' => $chat['customer_name'],
                'avatar_url' => $chat['customer_avatar']
            ];
        } else {
            // 客戶視角：看到管理員資訊（包括管理員作為客戶時）
            $formattedChat['admin'] = null;
            if ($chat['admin_id']) {
                $formattedChat['admin'] = [
                    'id' => (string)$chat['admin_id'],
                    'name' => $chat['admin_name'],
                    'avatar_url' => $chat['admin_avatar']
                ];
            }
        }
        
        $formattedList[] = $formattedChat;
    }
    
    // 回傳成功結果
    Response::success([
        'chat_list' => $formattedList,
        'total_count' => count($formattedList),
        'user_type' => $isAdmin ? 'admin' : 'customer'
    ]);
    
} catch (Exception $e) {
    error_log('Get Support Chat List API Error: ' . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}
?>
