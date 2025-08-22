<?php
/**
 * 全域未讀總計 API - 遵循聊天系統規格文件標準
 * 
 * 路徑：GET /api/chat/unreads/total
 * 
 * 實現規格文件標準：
 * - 計算所有聊天室的未讀總數
 * - 用於底部導航 badge 顯示
 * - 統一的計算邏輯：對方訊息且 id > 我的 last_read_message_id
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/ChatSecurity.php';


try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        Response::error('Method not allowed', 405);
    }

    // 驗證授權
    $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
    if (empty($auth_header) || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $m)) {
        throw new Exception('Authorization header required');
    }
    $user_id = TokenValidator::validateAuthHeader($auth_header);
    if (!$user_id) { throw new Exception('Invalid or expired token'); }
    $user_id = (int)$user_id;

    $db = Database::getInstance();

    // 規格文件標準：計算所有聊天室的總未讀數
    // 邏輯：對方訊息且 id > 我的 last_read_message_id
    $total_unread_sql = "
        SELECT 
            COUNT(DISTINCT cm.id) as total_unread
        FROM chat_messages cm
        JOIN chat_rooms cr ON cr.id = cm.room_id
        LEFT JOIN chat_reads r ON r.room_id = cm.room_id AND r.user_id = ?
        WHERE (cr.creator_id = ? OR cr.participant_id = ?)
          AND cm.from_user_id != ?
          AND cm.id > COALESCE(r.last_read_message_id, 0)
    ";
    
    $result = $db->query($total_unread_sql, [$user_id, $user_id, $user_id, $user_id])->fetch();
    $total_unread = (int)($result['total_unread'] ?? 0);

    // 按規格文件格式回傳
    Response::success([
        'total_unread' => $total_unread,
        'method' => 'room_based_via_last_read_pointer'
    ], 'Total unread count retrieved successfully');

} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>
