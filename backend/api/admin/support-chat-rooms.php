<?php
/**
 * 管理員客服聊天室列表 API
 * GET /api/admin/support-chat-rooms
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    // 驗證JWT Token（需要管理員權限）
    $tokenData = JWTManager::validateRequest();
    if (!$tokenData['valid']) {
        Response::error($tokenData['message'], 401);
    }
    
    // 檢查管理員權限
    $adminId = $tokenData['admin_id'] ?? null;
    if (!$adminId) {
        Response::error('Admin access required', 403);
    }
    
    $db = Database::getInstance()->getConnection();
    
    // 獲取查詢參數
    $page = max(1, (int)($_GET['page'] ?? 1));
    $perPage = min(100, max(10, (int)($_GET['per_page'] ?? 15)));
    $type = $_GET['type'] ?? '';
    $status = $_GET['status'] ?? '';
    $search = trim($_GET['search'] ?? '');
    
    $offset = ($page - 1) * $perPage;
    
    // 構建查詢條件
    $whereConditions = [];
    $params = [];
    
    if (!empty($type) && $type !== 'all') {
        $whereConditions[] = "se.type = ?";
        $params[] = $type;
    }
    
    if (!empty($status)) {
        $whereConditions[] = "se.status = ?";
        $params[] = $status;
    }
    
    if (!empty($search)) {
        $whereConditions[] = "(se.title LIKE ? OR u.name LIKE ? OR u.email LIKE ?)";
        $searchTerm = "%{$search}%";
        $params = array_merge($params, [$searchTerm, $searchTerm, $searchTerm]);
    }
    
    $whereClause = !empty($whereConditions) ? 'WHERE ' . implode(' AND ', $whereConditions) : '';
    
    // 查詢客服聊天室列表
    $sql = "
        SELECT 
            scr.id as room_id,
            scr.user_id,
            scr.admin_id,
            scr.created_at as room_created_at,
            u.name as customer_name,
            u.email as customer_email,
            u.avatar_url as customer_avatar,
            se.id as event_id,
            se.title as event_title,
            se.type,
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
             WHERE scm.room_id = scr.id 
             AND scm.sender_type = 'user'
             AND scm.created_at > COALESCE(
                 (SELECT last_read_at FROM support_chat_reads 
                  WHERE room_id = scr.id AND user_id = ? AND user_type = 'admin'), 
                 '1970-01-01'
             )) as unread_count
        FROM support_chat_rooms scr
        JOIN support_events se ON scr.event_id = se.id
        JOIN users u ON scr.user_id = u.id
        {$whereClause}
        ORDER BY 
            CASE WHEN scr.admin_id = ? THEN 0 ELSE 1 END,
            COALESCE(last_message_time, scr.created_at) DESC
        LIMIT ? OFFSET ?
    ";
    
    // 添加管理員ID參數用於未讀數計算和排序
    array_unshift($params, $adminId, $adminId);
    $params[] = $perPage;
    $params[] = $offset;
    
    $stmt = $db->prepare($sql);
    $stmt->execute($params);
    $chatRooms = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // 查詢總數
    $countSql = "
        SELECT COUNT(*) as total
        FROM support_chat_rooms scr
        JOIN support_events se ON scr.event_id = se.id
        JOIN users u ON scr.user_id = u.id
        {$whereClause}
    ";
    
    $countParams = array_slice($params, 2, -2); // 移除管理員ID和分頁參數
    $countStmt = $db->prepare($countSql);
    $countStmt->execute($countParams);
    $totalCount = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // 格式化聊天室資料
    $formattedChatRooms = array_map(function($room) use ($adminId) {
        return [
            'room_id' => (int)$room['room_id'],
            'event_id' => (int)$room['event_id'],
            'type' => $room['type'] ?: 'support',
            'status' => $room['event_status'],
            'title' => $room['event_title'] ?: 'Support Request',
            'user_name' => $room['customer_name'],
            'user_email' => $room['customer_email'],
            'user_avatar' => $room['customer_avatar'],
            'last_message' => $room['last_message'],
            'last_message_at' => $room['last_message_time'] ?: $room['room_created_at'],
            'is_claimed' => !empty($room['admin_id']),
            'admin_id' => $room['admin_id'] ? (int)$room['admin_id'] : null,
            'unread_count' => (int)$room['unread_count'],
            'created_at' => $room['room_created_at'],
            'updated_at' => $room['event_updated_at']
        ];
    }, $chatRooms);
    
    $pagination = [
        'current_page' => $page,
        'per_page' => $perPage,
        'total' => (int)$totalCount,
        'last_page' => ceil($totalCount / $perPage)
    ];
    
    Response::success([
        'chat_rooms' => $formattedChatRooms,
        'pagination' => $pagination
    ], 'Support chat rooms retrieved successfully');
    
} catch (Exception $e) {
    error_log("Admin Support Chat Rooms API Error: " . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}
?>
