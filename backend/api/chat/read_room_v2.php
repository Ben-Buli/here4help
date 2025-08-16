<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
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
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        Response::error('Method not allowed', 405);
    }

    $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
    if (empty($auth_header) || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $m)) {
        throw new Exception('Authorization header required');
    }
    $payload = validateToken($m[1]);
    if (!$payload) throw new Exception('Invalid or expired token');
    $user_id = (int)$payload['user_id'];

    $input = json_decode(file_get_contents('php://input'), true);
    $room_id = $input['room_id'] ?? null;
    
    if (!$room_id) {
        throw new Exception('room_id is required');
    }

    $db = Database::getInstance();
    
    // 開始事務
    $db->beginTransaction();
    
    try {
        // 1. 驗證用戶是否為該聊天室的參與者
        $roomCheckSQL = "
            SELECT id, creator_id, participant_id, task_id 
            FROM chat_rooms 
            WHERE id = ? AND (creator_id = ? OR participant_id = ?)
        ";
        $roomInfo = $db->query($roomCheckSQL, [$room_id, $user_id, $user_id])->fetch();
        
        if (!$roomInfo) {
            throw new Exception('Room not found or access denied');
        }
        
        // 2. 獲取該聊天室的最新訊息 ID
        $lastMessageSQL = "SELECT MAX(id) as last_message_id FROM chat_messages WHERE room_id = ?";
        $lastMessageResult = $db->query($lastMessageSQL, [$room_id])->fetch();
        $lastMessageId = $lastMessageResult['last_message_id'] ?? 0;
        
        // 3. Upsert 更新用戶的已讀記錄（確保只能前進，不會倒退）
        $upsertSQL = "
            INSERT INTO chat_reads (user_id, room_id, last_read_message_id, updated_at)
            VALUES (?, ?, ?, NOW())
            ON DUPLICATE KEY UPDATE 
                last_read_message_id = GREATEST(last_read_message_id, VALUES(last_read_message_id)),
                updated_at = NOW()
        ";
        $db->query($upsertSQL, [$user_id, $room_id, $lastMessageId]);
        
        // 4. 獲取更新後的已讀記錄
        $readStatusSQL = "SELECT last_read_message_id FROM chat_reads WHERE user_id = ? AND room_id = ?";
        $readStatus = $db->query($readStatusSQL, [$user_id, $room_id])->fetch();
        $actualLastRead = $readStatus['last_read_message_id'] ?? 0;
        
                    // 5. 計算該聊天室當前未讀數（應該為 0）
            $unreadSQL = "
                SELECT COUNT(*) as unread_count
                FROM chat_messages cm
                JOIN chat_rooms cr ON cr.id = cm.room_id
                WHERE cm.room_id = ?
                  AND cm.from_user_id != ?
                  AND cm.id > ?
            ";
        $unreadResult = $db->query($unreadSQL, [$room_id, $user_id, $actualLastRead])->fetch();
        $unreadCount = (int)$unreadResult['unread_count'];
        
        $db->commit();
        
        Response::success([
            'room_id' => (int)$room_id,
            'last_read_message_id' => (int)$actualLastRead,
            'unread_count' => $unreadCount,
            'method' => 'mark_read_to_latest_v2',
            'user_role' => $roomInfo['creator_id'] == $user_id ? 'creator' : 'participant'
        ], 'Room marked as read successfully');
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }

} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>
