<?php
require_once __DIR__ . '/bootstrap.php';
// 載入 PHP 8.4 相容性配置

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';



try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        Response::error('Method not allowed', 405);
    }

    $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
    if (empty($auth_header) || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $m)) {
        throw new Exception('Authorization header required');
    }
    $user_id = TokenValidator::validateAuthHeader($auth_header);
    if (!$user_id) { throw new Exception('Invalid or expired token'); }
    $user_id = (int)$user_id;

    $input = json_decode(file_get_contents('php://input'), true);
    $room_id = $input['room_id'] ?? null;
    
    if (!$room_id) {
        throw new Exception('room_id is required');
    }

    $db = Database::getInstance();
    
    // 開始事務
    $db->beginTransaction();
    
    try {
        // 1. 驗證用戶是否為該聊天室的參與者（支援一般聊天室和客服聊天室）
        $roomCheckSQL = "
            SELECT 'regular' as source, id, creator_id, participant_id, task_id 
            FROM chat_rooms 
            WHERE id = ? AND (creator_id = ? OR participant_id = ?)
            UNION ALL
            SELECT 'support' as source, id, user_id as creator_id, admin_id as participant_id, NULL as task_id
            FROM support_chat_rooms 
            WHERE id = ? AND (user_id = ? OR admin_id = ?)
            LIMIT 1
        ";
        $roomInfo = $db->query($roomCheckSQL, [$room_id, $user_id, $user_id, $room_id, $user_id, $user_id])->fetch();
        
        if (!$roomInfo) {
            throw new Exception('Room not found or access denied');
        }
        
        // 2. 根據聊天室類型獲取該聊天室的最新訊息 ID
        if ($roomInfo['source'] === 'support') {
            $lastMessageSQL = "SELECT MAX(id) as last_message_id FROM support_chat_messages WHERE room_id = ?";
        } else {
            $lastMessageSQL = "SELECT MAX(id) as last_message_id FROM chat_messages WHERE room_id = ?";
        }
        $lastMessageResult = $db->query($lastMessageSQL, [$room_id])->fetch();
        $lastMessageId = $lastMessageResult['last_message_id'] ?? 0;
        
        // 3. 根據聊天室類型更新用戶的已讀記錄（確保只能前進，不會倒退）
        if ($roomInfo['source'] === 'support') {
            $upsertSQL = "
                INSERT INTO support_chat_reads (user_id, admin_id, role, room_id, last_read_message_id, updated_at)
                VALUES (?, NULL, 'user', ?, ?, NOW())
                ON DUPLICATE KEY UPDATE 
                    last_read_message_id = GREATEST(last_read_message_id, VALUES(last_read_message_id)),
                    updated_at = NOW()
            ";
        } else {
            $upsertSQL = "
                INSERT INTO chat_reads (user_id, room_id, last_read_message_id, updated_at)
                VALUES (?, ?, ?, NOW())
                ON DUPLICATE KEY UPDATE 
                    last_read_message_id = GREATEST(last_read_message_id, VALUES(last_read_message_id)),
                    updated_at = NOW()
            ";
        }
        $db->query($upsertSQL, [$user_id, $room_id, $lastMessageId]);
        
        // 4. 根據聊天室類型獲取更新後的已讀記錄
        if ($roomInfo['source'] === 'support') {
            $readStatusSQL = "SELECT last_read_message_id FROM support_chat_reads WHERE user_id = ? AND role = 'user' AND room_id = ?";
        } else {
            $readStatusSQL = "SELECT last_read_message_id FROM chat_reads WHERE user_id = ? AND room_id = ?";
        }
        $readStatus = $db->query($readStatusSQL, [$user_id, $room_id])->fetch();
        $actualLastRead = $readStatus['last_read_message_id'] ?? 0;
        
        // 5. 根據聊天室類型計算該聊天室當前未讀數（應該為 0）
        if ($roomInfo['source'] === 'support') {
            $unreadSQL = "
                SELECT COUNT(*) as unread_count
                FROM support_chat_messages scm
                JOIN support_chat_rooms scr ON scr.id = scm.room_id
                WHERE scm.room_id = ?
                  AND scm.user_id != ?
                  AND scm.role = 'user'
                  AND scm.id > ?
            ";
        } else {
            $unreadSQL = "
                SELECT COUNT(*) as unread_count
                FROM chat_messages cm
                JOIN chat_rooms cr ON cr.id = cm.room_id
                WHERE cm.room_id = ?
                  AND cm.from_user_id != ?
                  AND cm.id > ?
            ";
        }
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
