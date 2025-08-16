<?php
/**
 * 統一標記已讀 API - 遵循聊天系統規格文件標準
 * 
 * 路徑：POST /api/chat/rooms/{roomId}/read
 * 
 * 實現規格文件標準：
 * - 權限驗證：確保用戶為該房間參與者
 * - 冪等操作：重複調用結果一致
 * - 只前進不後退：last_read_message_id 只能增大
 * - 標記到最新：預設標記到該房間最新訊息
 */

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

    // 驗證授權
    $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
    if (empty($auth_header) || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $m)) {
        throw new Exception('Authorization header required');
    }
    $payload = validateToken($m[1]);
    if (!$payload) throw new Exception('Invalid or expired token');
    $user_id = (int)$payload['user_id'];

    // 解析請求參數
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        Response::error('Invalid JSON input', 400);
    }

    $room_id = $input['room_id'] ?? null;
    $up_to_message_id = $input['up_to_message_id'] ?? null; // 可選，預設為最新

    if (!$room_id) {
        Response::error('room_id is required', 400);
    }

    $db = Database::getInstance();
    $db->beginTransaction();
    
    try {
        // 1. 權限驗證：確保用戶為該房間參與者
        $room_check_sql = "
            SELECT id, creator_id, participant_id, task_id 
            FROM chat_rooms 
            WHERE id = ? AND (creator_id = ? OR participant_id = ?)
        ";
        $room_info = $db->query($room_check_sql, [$room_id, $user_id, $user_id])->fetch();
        
        if (!$room_info) {
            throw new Exception('Room not found or access denied');
        }
        
        // 2. 獲取要標記的訊息 ID（如果未指定，則使用最新）
        if ($up_to_message_id === null) {
            $latest_message_sql = "SELECT MAX(id) as latest_id FROM chat_messages WHERE room_id = ?";
            $latest_result = $db->query($latest_message_sql, [$room_id])->fetch();
            $up_to_message_id = $latest_result['latest_id'] ?? 0;
        }
        
        // 3. Upsert 更新已讀記錄（只前進不後退）
        $upsert_sql = "
            INSERT INTO chat_reads (user_id, room_id, last_read_message_id, updated_at)
            VALUES (?, ?, ?, NOW())
            ON DUPLICATE KEY UPDATE 
                last_read_message_id = GREATEST(last_read_message_id, VALUES(last_read_message_id)),
                updated_at = NOW()
        ";
        $db->query($upsert_sql, [$user_id, $room_id, $up_to_message_id]);
        
        // 4. 獲取更新後的已讀狀態
        $read_status_sql = "SELECT last_read_message_id, updated_at FROM chat_reads WHERE user_id = ? AND room_id = ?";
        $read_status = $db->query($read_status_sql, [$user_id, $room_id])->fetch();
        $actual_last_read = $read_status['last_read_message_id'] ?? 0;
        
        // 5. 計算更新後的未讀數（應該為 0）
        $unread_sql = "
            SELECT COUNT(DISTINCT cm.id) as unread_count
            FROM chat_messages cm
            JOIN chat_rooms cr ON cr.id = cm.room_id
            WHERE cm.room_id = ?
              AND cm.from_user_id != ?
              AND cm.id > ?
        ";
        $unread_result = $db->query($unread_sql, [$room_id, $user_id, $actual_last_read])->fetch();
        $unread_count = (int)($unread_result['unread_count'] ?? 0);
        
        $db->commit();
        
        // 按規格文件格式回傳
        Response::success([
            'room_id' => $room_id,
            'last_read_message_id' => (int)$actual_last_read,
            'unread_count' => $unread_count,
            'read_time' => $read_status['updated_at'] ?? null,
            'method' => 'mark_read_to_latest'
        ], 'Room marked as read successfully');
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }

} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>
