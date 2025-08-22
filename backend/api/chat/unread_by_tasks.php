<?php
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


try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        Response::error('Method not allowed', 405);
    }

    $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
    if (empty($auth_header) || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $m)) {
        throw new Exception('Authorization header required');
    }
    $user_id = TokenValidator::validateAuthHeader($auth_header);
    if (!$user_id) { throw new Exception('Invalid or expired token'); }
    $user_id = (int)$user_id;
    
    // 支援分頁過濾參數
    $scope = $_GET['scope'] ?? 'all'; // 'posted', 'myworks', 'all'
    if (!in_array($scope, ['posted', 'myworks', 'all'])) {
        $scope = 'all';
    }

    $db = Database::getInstance();
    $unreadByRoom = [];
    $total = 0;

    // 基於 creator/participant 角色的精確未讀計算
    // 使用現有的 chat_rooms.creator_id 和 participant_id 欄位
    
    if ($scope === 'posted' || $scope === 'all') {
        // Posted Tasks: 我是 creator，計算 participant 發送給我的未讀訊息
        $postedSQL = "
            SELECT 
                cr.id AS room_id,
                SUM(CASE WHEN cm.from_user_id = cr.participant_id 
                           AND cm.id > COALESCE(r.last_read_message_id, 0)
                         THEN 1 ELSE 0 END) AS unread_count
            FROM chat_rooms cr
            LEFT JOIN chat_reads r ON r.room_id = cr.id AND r.user_id = ?
            JOIN chat_messages cm ON cm.room_id = cr.id
            WHERE cr.creator_id = ?
            GROUP BY cr.id
            HAVING unread_count > 0
        ";
        
        $postedResults = $db->fetchAll($postedSQL, [$user_id, $user_id]);
        foreach ($postedResults as $row) {
            $roomId = (string)$row['room_id'];
            $count = (int)$row['unread_count'];
            $unreadByRoom[$roomId] = $count;
            $total += $count;
        }
    }

    if ($scope === 'myworks' || $scope === 'all') {
        // My Works: 我是 participant，計算 creator 發送給我的未讀訊息
        $myWorksSQL = "
            SELECT 
                cr.id AS room_id,
                SUM(CASE WHEN cm.from_user_id = cr.creator_id 
                           AND cm.id > COALESCE(r.last_read_message_id, 0)
                         THEN 1 ELSE 0 END) AS unread_count
            FROM chat_rooms cr
            LEFT JOIN chat_reads r ON r.room_id = cr.id AND r.user_id = ?
            JOIN chat_messages cm ON cm.room_id = cr.id
            WHERE cr.participant_id = ?
            GROUP BY cr.id
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
    }

    Response::success([
        'total' => $total,
        'by_room' => $unreadByRoom,
        'scope' => $scope,
        'method' => 'creator_participant_role_based'
    ], 'Unread counts calculated by role-based logic');

} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>
