<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once '../../config/database.php';
require_once '../../utils/Response.php';

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

    $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
    if (empty($auth_header) || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $m)) {
        throw new Exception('Authorization header required');
    }
    $payload = validateToken($m[1]);
    if (!$payload) throw new Exception('Invalid or expired token');
    $user_id = (int)$payload['user_id'];

    $db = Database::getInstance();

    // 新方法：基於任務申請關係計算未讀，不依賴 chat_rooms.creator_id/participant_id
    $unreadByRoom = [];
    $total = 0;

    // 1. 對於我發布的任務（Posted Tasks）- 計算應徵者發送給我的未讀訊息
    $postedTasksSQL = "
        SELECT 
            cr.id AS room_id,
            t.id AS task_id,
            ta.user_id AS applicant_id,
            SUM(CASE WHEN cm.from_user_id = ta.user_id AND cm.id > COALESCE(reads.last_read_message_id, 0)
                     THEN 1 ELSE 0 END) AS unread_count
        FROM tasks t
        JOIN task_applications ta ON t.id = ta.task_id
        JOIN chat_rooms cr ON cr.task_id = t.id
        JOIN chat_messages cm ON cm.room_id = cr.id
        LEFT JOIN chat_reads reads ON reads.room_id = cr.id AND reads.user_id = ?
        WHERE t.creator_id = ?
        GROUP BY cr.id, t.id, ta.user_id
        HAVING unread_count > 0
    ";
    
    $postedResults = $db->fetchAll($postedTasksSQL, [$user_id, $user_id]);
    foreach ($postedResults as $row) {
        $roomId = (string)$row['room_id'];
        $count = (int)$row['unread_count'];
        $unreadByRoom[$roomId] = $count;
        $total += $count;
    }

    // 2. 對於我申請的任務（My Works）- 計算任務建立者發送給我的未讀訊息
    $myWorksSQL = "
        SELECT 
            cr.id AS room_id,
            t.id AS task_id,
            t.creator_id,
            SUM(CASE WHEN cm.from_user_id = t.creator_id AND cm.id > COALESCE(reads.last_read_message_id, 0)
                     THEN 1 ELSE 0 END) AS unread_count
        FROM task_applications ta
        JOIN tasks t ON ta.task_id = t.id
        JOIN chat_rooms cr ON cr.task_id = t.id
        JOIN chat_messages cm ON cm.room_id = cr.id
        LEFT JOIN chat_reads reads ON reads.room_id = cr.id AND reads.user_id = ?
        WHERE ta.user_id = ?
        GROUP BY cr.id, t.id, t.creator_id
        HAVING unread_count > 0
    ";
    
    $myWorksResults = $db->fetchAll($myWorksSQL, [$user_id, $user_id]);
    foreach ($myWorksResults as $row) {
        $roomId = (string)$row['room_id'];
        $count = (int)$row['unread_count'];
        if (!isset($unreadByRoom[$roomId])) {
            $unreadByRoom[$roomId] = $count;
            $total += $count;
        }
    }

    Response::success([
        'total' => $total,
        'by_room' => $unreadByRoom,
        'method' => 'task_based_calculation'
    ], 'Unread counts calculated from task relationships');

} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>
