<?php
/**
 * 統一聊天室列表 API - 遵循聊天系統規格文件標準
 * 
 * 路徑：GET /api/chat/rooms?scope=posted|myworks&with_unread=1
 * 
 * 實現規格文件標準：
 * - scope 參數：posted(我=creator), myworks(我=participant)
 * - 包含未讀數計算
 * - 返回聊天對象資訊
 * - 最新訊息預覽
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once '../../config/database.php';
require_once '../../utils/Response.php';
require_once '../../utils/ChatSecurity.php';

function validateToken($token) {
    try {
        $decoded = base64_decode($token);
        if ($decoded === false) return null;
        $payload = json_decode($decoded, true);
        if (!$payload || !isset($payload['user_id']) || !isset($payload['exp'])) return null;
        if ($payload['exp'] < time()) return null;
        return $payload;
    } catch (Exception $e) { return null; }
}

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        Response::error('Method not allowed', 405);
    }

    // 驗證授權
    $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
    if (empty($auth_header) || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $m)) {
        throw new Exception('Authorization header required');
    }
    $payload = validateToken($m[1]);
    if (!$payload) throw new Exception('Invalid or expired token');
    $user_id = (int)$payload['user_id'];
    
    // 解析和驗證參數
    $scope = ChatSecurity::sanitizeInput($_GET['scope'] ?? 'all', 'string');
    $with_unread = isset($_GET['with_unread']) && $_GET['with_unread'] === '1';
    $limit = max(1, min(100, ChatSecurity::sanitizeInput($_GET['limit'] ?? 20, 'int')));
    $offset = max(0, ChatSecurity::sanitizeInput($_GET['offset'] ?? 0, 'int'));
    
    if (!ChatSecurity::canAccessScope($user_id, $scope)) {
        ChatSecurity::logSecurityEvent('invalid_scope_access', $user_id, ['scope' => $scope, 'endpoint' => 'rooms']);
        Response::error('Invalid scope. Must be one of: posted, myworks, all', 400);
    }

    $db = Database::getInstance();
    $rooms = [];

    // 構建查詢條件
    $where_conditions = [];
    $params = [];

    if ($scope === 'posted') {
        $where_conditions[] = 'cr.creator_id = ?';
        $params[] = $user_id;
    } elseif ($scope === 'myworks') {
        $where_conditions[] = 'cr.participant_id = ?';
        $params[] = $user_id;
    } else { // all
        $where_conditions[] = '(cr.creator_id = ? OR cr.participant_id = ?)';
        $params[] = $user_id;
        $params[] = $user_id;
    }

    $where_clause = implode(' AND ', $where_conditions);

    // 主查詢：獲取聊天室列表
    $sql = "
        SELECT 
            cr.id as room_id,
            cr.task_id,
            cr.creator_id,
            cr.participant_id,
            cr.created_at as room_created_at,
            
            -- 任務資訊
            t.title as task_title,
            t.description as task_description,
            t.status_id,
            ts.name as task_status,
            ts.display_name as task_status_display,
            t.updated_at as task_updated_at,
            
            -- 聊天對象資訊（依 scope 判斷）
            CASE 
                WHEN cr.creator_id = ? THEN participant.name
                ELSE creator.name
            END as counterpart_name,
            CASE 
                WHEN cr.creator_id = ? THEN participant.avatar_url
                ELSE creator.avatar_url
            END as counterpart_avatar,
            CASE 
                WHEN cr.creator_id = ? THEN cr.participant_id
                ELSE cr.creator_id
            END as counterpart_user_id,
            
            -- 最新訊息
            latest_msg.content as last_message,
            latest_msg.created_at as last_message_time,
            latest_msg.from_user_id as last_message_sender_id" .
            
            ($with_unread ? ",
            -- 未讀數計算
            COALESCE(unread_count.count, 0) as unread_count" : "") . "
            
        FROM chat_rooms cr
        LEFT JOIN tasks t ON cr.task_id = t.id
        LEFT JOIN task_statuses ts ON t.status_id = ts.id
        LEFT JOIN users creator ON cr.creator_id = creator.id
        LEFT JOIN users participant ON cr.participant_id = participant.id
        
        -- 最新訊息子查詢
        LEFT JOIN (
            SELECT 
                room_id,
                content,
                created_at,
                from_user_id,
                ROW_NUMBER() OVER (PARTITION BY room_id ORDER BY created_at DESC) as rn
            FROM chat_messages
        ) latest_msg ON cr.id = latest_msg.room_id AND latest_msg.rn = 1" .
        
        ($with_unread ? "
        -- 未讀數計算子查詢
        LEFT JOIN (
            SELECT 
                cm.room_id,
                COUNT(DISTINCT cm.id) as count
            FROM chat_messages cm
            LEFT JOIN chat_reads r ON cm.room_id = r.room_id AND r.user_id = ?
            WHERE cm.from_user_id != ?
              AND cm.id > COALESCE(r.last_read_message_id, 0)
            GROUP BY cm.room_id
        ) unread_count ON cr.id = unread_count.room_id" : "") . "
        
        WHERE $where_clause
        ORDER BY latest_msg.created_at DESC, cr.created_at DESC
        LIMIT ? OFFSET ?
    ";

    // 組合參數
    $query_params = [
        $user_id, // counterpart_name CASE
        $user_id, // counterpart_avatar CASE  
        $user_id  // counterpart_user_id CASE
    ];
    
    if ($with_unread) {
        $query_params[] = $user_id; // unread_count 子查詢的 user_id
        $query_params[] = $user_id; // unread_count 子查詢的 from_user_id 排除
    }
    
    $query_params = array_merge($query_params, $params, [$limit, $offset]);

    $rooms = $db->fetchAll($sql, $query_params);

    // 格式化回傳數據
    $formatted_rooms = [];
    foreach ($rooms as $room) {
        $formatted_room = [
            'room_id' => $room['room_id'],
            'task_id' => $room['task_id'],
            'counterpart_user' => [
                'id' => (int)$room['counterpart_user_id'],
                'name' => $room['counterpart_name'],
                'avatar_url' => $room['counterpart_avatar']
            ],
            'last_message' => $room['last_message'],
            'last_message_time' => $room['last_message_time'],
            'updated_at' => $room['last_message_time'] ?: $room['room_created_at'],
            'task' => [
                'id' => $room['task_id'],
                'title' => $room['task_title'],
                'status' => $room['task_status'],
                'status_display' => $room['task_status_display']
            ]
        ];
        
        if ($with_unread) {
            $formatted_room['unread_count'] = (int)$room['unread_count'];
        }
        
        $formatted_rooms[] = $formatted_room;
    }

    Response::success([
        'rooms' => $formatted_rooms,
        'scope' => $scope,
        'with_unread' => $with_unread,
        'total' => count($formatted_rooms),
        'limit' => $limit,
        'offset' => $offset
    ], 'Chat rooms retrieved successfully');

} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>
