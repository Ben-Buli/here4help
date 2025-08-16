<?php
/**
 * 統一未讀計算 API - 遵循聊天系統規格文件標準
 * 
 * 支援路徑：
 * GET /api/chat/unreads?scope=posted|myworks|all
 * 
 * 實現規格文件的標準未讀計算邏輯：
 * - condition: from_user_id=對方 AND message.id > my.last_read_message_id
 * - roles: posted(我=creator), myworks(我=participant), all(兩者合併)
 * - 若無紀錄 → last_read_message_id=0
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
    
    // 解析 scope 參數
    $scope = $_GET['scope'] ?? 'all';
    if (!in_array($scope, ['posted', 'myworks', 'all'])) {
        Response::error('Invalid scope. Must be one of: posted, myworks, all', 400);
    }

    $db = Database::getInstance();
    $by_room = [];
    $total = 0;

    // 規格文件標準：統一未讀計算邏輯
    // condition: 對方=from_user_id ≠ 我 AND message.id > my.last_read_message_id(room)
    
    if ($scope === 'posted' || $scope === 'all') {
        // Posted Tasks: 我=creator, 對方=participant
        // 計算 participant 發送給我的未讀訊息
        $posted_sql = "
            SELECT 
                cr.id AS room_id,
                COUNT(DISTINCT cm.id) AS unread_count
            FROM chat_rooms cr
            LEFT JOIN chat_reads r ON r.room_id = cr.id AND r.user_id = ?
            JOIN chat_messages cm ON cm.room_id = cr.id
            WHERE cr.creator_id = ?
              AND cm.from_user_id = cr.participant_id
              AND cm.id > COALESCE(r.last_read_message_id, 0)
            GROUP BY cr.id
            HAVING unread_count > 0
        ";
        
        $posted_results = $db->fetchAll($posted_sql, [$user_id, $user_id]);
        foreach ($posted_results as $row) {
            $room_id = (string)$row['room_id'];
            $count = (int)$row['unread_count'];
            $by_room[$room_id] = $count;
            $total += $count;
        }
    }

    if ($scope === 'myworks' || $scope === 'all') {
        // My Works: 我=participant, 對方=creator
        // 計算 creator 發送給我的未讀訊息
        $myworks_sql = "
            SELECT 
                cr.id AS room_id,
                COUNT(DISTINCT cm.id) AS unread_count
            FROM chat_rooms cr
            LEFT JOIN chat_reads r ON r.room_id = cr.id AND r.user_id = ?
            JOIN chat_messages cm ON cm.room_id = cr.id
            WHERE cr.participant_id = ?
              AND cm.from_user_id = cr.creator_id
              AND cm.id > COALESCE(r.last_read_message_id, 0)
            GROUP BY cr.id
            HAVING unread_count > 0
        ";
        
        $myworks_results = $db->fetchAll($myworks_sql, [$user_id, $user_id]);
        foreach ($myworks_results as $row) {
            $room_id = (string)$row['room_id'];
            $count = (int)$row['unread_count'];
            // 避免重複計算（當同一房間在 posted 和 myworks 都有時）
            if (!isset($by_room[$room_id])) {
                $by_room[$room_id] = $count;
                $total += $count;
            }
        }
    }

    // 按規格文件格式回傳
    Response::success([
        'total' => $total,
        'by_room' => $by_room,
        'scope' => $scope,
        'method' => 'room_based_via_last_read_pointer'
    ], 'Unread counts retrieved successfully');

} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>
