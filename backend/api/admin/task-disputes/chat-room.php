<?php
/**
 * 管理員查看爭議聊天室
 * GET /api/admin/task-disputes/{dispute_id}/chat-room.php
 */

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../utils/JWTManager.php';
require_once __DIR__ . '/../../../utils/Response.php';
require_once __DIR__ . '/../../../utils/UserActiveLogger.php';

header('Content-Type: application/json');
Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::methodNotAllowed('Only GET method is allowed');
}

try {
    // JWT 認證
    $tokenData = JWTManager::validateRequest();
    if (!$tokenData['valid']) {
        Response::unauthorized($tokenData['message']);
    }

    // 檢查管理員權限
    $adminId = $tokenData['admin_id'] ?? null;
    if (!$adminId) {
        Response::forbidden('Admin access required');
    }
    
    // 獲取爭議ID
    $disputeId = $_GET['dispute_id'] ?? null;
    if (!$disputeId) {
        Response::badRequest('Dispute ID is required');
    }
    
    // 資料庫連接
    $db = Database::getInstance()->getConnection();
    
    // 驗證管理員角色
    $adminCheck = $db->prepare("
        SELECT ar.name as role_name, a.username
        FROM admins a
        JOIN admin_roles ar ON a.role_id = ar.id
        WHERE a.id = ?
    ");
    $adminCheck->execute([$adminId]);
    $admin = $adminCheck->fetch(PDO::FETCH_ASSOC);
    
    if (!$admin || !in_array($admin['role_name'], ['admin', 'super_admin'])) {
        Response::forbidden('Insufficient permissions to view dispute chat rooms');
    }
    
    // 獲取爭議資訊
    $disputeQuery = $db->prepare("
        SELECT 
            tde.id,
            tde.task_id,
            tde.task_dispute_chat_room_id,
            tde.title,
            tde.description,
            tde.status,
            tde.decision_result,
            tde.decision_note,
            tde.created_at,
            tde.updated_at,
            t.title as task_title,
            t.creator_id,
            t.participant_id,
            t.reward_point,
            ts.code as task_status_code,
            ts.display_name as task_status_display
        FROM task_dispute_events tde
        JOIN tasks t ON tde.task_id = t.id
        LEFT JOIN task_statuses ts ON t.status_id = ts.id
        WHERE tde.id = ?
    ");
    $disputeQuery->execute([$disputeId]);
    $dispute = $disputeQuery->fetch(PDO::FETCH_ASSOC);
    
    if (!$dispute) {
        Response::notFound('Dispute not found');
    }
    
    $chatRoomId = $dispute['task_dispute_chat_room_id'];
    $taskId = $dispute['task_id'];
    
    // 獲取聊天室資訊
    $roomQuery = $db->prepare("
        SELECT id, type, task_id, created_at
        FROM chat_rooms
        WHERE id = ?
    ");
    $roomQuery->execute([$chatRoomId]);
    $chatRoom = $roomQuery->fetch(PDO::FETCH_ASSOC);
    
    if (!$chatRoom) {
        Response::notFound('Chat room not found');
    }
    
    // 獲取聊天訊息 (完整歷史)
    $messagesQuery = $db->prepare("
        SELECT 
            cm.id,
            cm.room_id,
            cm.from_user_id,
            cm.content,
            cm.kind,
            cm.image_url,
            cm.resume_data,
            cm.created_at,
            u.name as user_name,
            u.avatar_url as user_avatar
        FROM chat_messages cm
        LEFT JOIN users u ON cm.from_user_id = u.id
        WHERE cm.room_id = ?
        ORDER BY cm.created_at ASC
    ");
    $messagesQuery->execute([$chatRoomId]);
    $messages = $messagesQuery->fetchAll(PDO::FETCH_ASSOC);
    
    // 獲取參與用戶資訊
    $userIds = array_unique(array_filter([
        $dispute['creator_id'],
        $dispute['participant_id']
    ]));
    
    $users = [];
    if (!empty($userIds)) {
        $userPlaceholders = str_repeat('?,', count($userIds) - 1) . '?';
        $usersQuery = $db->prepare("
            SELECT 
                id,
                name,
                email,
                avatar_url
            FROM users
            WHERE id IN ({$userPlaceholders})
        ");
        $usersQuery->execute($userIds);
        $userResults = $usersQuery->fetchAll(PDO::FETCH_ASSOC);
        
        foreach ($userResults as $user) {
            $users[$user['id']] = [
                'id' => (int)$user['id'],
                'name' => $user['name'],
                'email' => $user['email'],
                'avatar_url' => $user['avatar_url']
            ];
        }
    }
    
    // 格式化訊息資料
    $formattedMessages = array_map(function($message) use ($users) {
        $messageData = [
            'id' => (int)$message['id'],
            'room_id' => $message['room_id'],
            'from_user_id' => $message['from_user_id'] ? (int)$message['from_user_id'] : null,
            'content' => $message['content'],
            'kind' => $message['kind'],
            'created_at' => $message['created_at'],
            'user_name' => $message['user_name'] ?? 'System',
            'user_avatar' => $message['user_avatar']
        ];
        
        // 添加特殊內容
        if ($message['image_url']) {
            $messageData['image_url'] = $message['image_url'];
        }
        
        if ($message['resume_data']) {
            $messageData['resume_data'] = json_decode($message['resume_data'], true);
        }
        
        return $messageData;
    }, $messages);
    
    // 記錄管理員查看操作
    UserActiveLogger::logAction(
        $db, 
        $adminId, 
        'dispute_chat_viewed',
        'dispute_management', 
        null, 
        null,
        "Admin viewed dispute chat room for dispute ID: {$disputeId}",
        'admin', 
        $adminId, 
        null, 
        null,
        [
            'dispute_id' => $disputeId,
            'chat_room_id' => $chatRoomId,
            'task_id' => $taskId
        ]
    );
    
    Response::success([
        'chat_room' => [
            'id' => $chatRoom['id'],
            'type' => $chatRoom['type'],
            'task_id' => $chatRoom['task_id'],
            'created_at' => $chatRoom['created_at']
        ],
        'task' => [
            'id' => $dispute['task_id'],
            'title' => $dispute['task_title'],
            'creator_id' => (int)$dispute['creator_id'],
            'participant_id' => $dispute['participant_id'] ? (int)$dispute['participant_id'] : null,
            'reward_point' => (int)$dispute['reward_point'],
            'status' => [
                'code' => $dispute['task_status_code'],
                'display_name' => $dispute['task_status_display']
            ]
        ],
        'messages' => $formattedMessages,
        'users' => $users,
        'dispute_info' => [
            'id' => (int)$dispute['id'],
            'title' => $dispute['title'],
            'description' => $dispute['description'],
            'status' => $dispute['status'],
            'decision_result' => $dispute['decision_result'],
            'decision_note' => $dispute['decision_note'],
            'created_at' => $dispute['created_at'],
            'updated_at' => $dispute['updated_at']
        ],
        'meta' => [
            'total_messages' => count($formattedMessages),
            'viewed_by_admin' => $admin['username'],
            'viewed_at' => date('Y-m-d H:i:s')
        ]
    ], 'Chat room data retrieved successfully');

} catch (PDOException $e) {
    error_log("Database error in admin chat room view: " . $e->getMessage());
    Response::serverError('Database error occurred');
} catch (Exception $e) {
    error_log("Error in admin chat room view: " . $e->getMessage());
    Response::serverError('An error occurred while retrieving chat room data');
}
?>
