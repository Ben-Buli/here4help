<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit(0); }

require_once '../../config/database.php';
require_once '../../utils/TokenValidator.php';
require_once '../../utils/Response.php';



try {
  if ($_SERVER['REQUEST_METHOD'] !== 'GET' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
  }

  // Auth
  $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
  if (empty($auth_header) || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $m)) {
    throw new Exception('Authorization header required');
  }
  $user_id = TokenValidator::validateAuthHeader($auth_header);
  if (!$user_id) { throw new Exception('Invalid or expired token'); }
  $user_id = (int)$user_id;

  $db = Database::getInstance();
  
  // 從 GET 參數或 POST body 獲取參數
  if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $task_id = $_GET['task_id'] ?? null;
    $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 50;
    $offset = isset($_GET['offset']) ? (int)$_GET['offset'] : 0;
  } else {
    $input = json_decode(file_get_contents('php://input'), true) ?? [];
    $task_id = isset($input['task_id']) ? (string)$input['task_id'] : null;
    $limit = isset($input['limit']) ? (int)$input['limit'] : 50;
    $offset = isset($input['offset']) ? (int)$input['offset'] : 0;
  }

  // 構建查詢條件
  $where_conditions = ['(cr.creator_id = ? OR cr.participant_id = ?)'];
  $params = [$user_id, $user_id];

  if ($task_id !== null) {
    $where_conditions[] = 'cr.task_id = ?';
    $params[] = $task_id;
  }

  $where_clause = implode(' AND ', $where_conditions);

  // 獲取聊天房間列表
  $rooms = $db->fetchAll("
    SELECT 
      cr.id as room_id,
      cr.task_id,
      cr.creator_id,
      cr.participant_id,
      cr.created_at as room_created_at,
      t.title as task_title,
      t.description as task_description,
      t.status_id,
      ts.name as task_status,
      ts.display_name as task_status_display,
              creator.name as creator_name,
        creator.avatar_url as creator_avatar,
        participant.name as participant_name,
      participant.avatar_url as participant_avatar,
      -- 最新訊息
      latest_msg.content as last_message,
      latest_msg.created_at as last_message_time,
      latest_msg.from_user_id as last_message_sender_id,
      -- 未讀訊息數量
      COALESCE(unread_count.count, 0) as unread_count
    FROM chat_rooms cr
    LEFT JOIN tasks t ON cr.task_id = t.id
    LEFT JOIN task_statuses ts ON t.status_id = ts.id
    LEFT JOIN users creator ON cr.creator_id = creator.id
    LEFT JOIN users participant ON cr.participant_id = participant.id
    LEFT JOIN (
      SELECT 
        room_id,
        message,
        created_at,
        from_user_id
      FROM chat_messages cm1
      WHERE created_at = (
        SELECT MAX(created_at)
        FROM chat_messages cm2
        WHERE cm2.room_id = cm1.room_id
      )
    ) latest_msg ON cr.id = latest_msg.room_id
    LEFT JOIN (
      SELECT 
        cm.room_id,
        COUNT(*) as count
      FROM chat_messages cm
      LEFT JOIN chat_reads cr ON cm.room_id = cr.room_id AND cr.user_id = ?
      WHERE cm.id > COALESCE(cr.last_read_message_id, 0)
      GROUP BY cm.room_id
    ) unread_count ON cr.id = unread_count.room_id
    WHERE $where_clause
    ORDER BY latest_msg.created_at DESC, cr.created_at DESC
    LIMIT ? OFFSET ?
  ", array_merge([$user_id], $params, [$limit, $offset]));

  // 格式化資料
  foreach ($rooms as &$room) {
    $room['room_created_at'] = date('Y-m-d H:i:s', strtotime($room['room_created_at']));
    $room['last_message_time'] = $room['last_message_time'] ? date('Y-m-d H:i:s', strtotime($room['last_message_time'])) : null;
    $room['unread_count'] = (int)$room['unread_count'];
    
    // 確定對方用戶資訊
    if ($room['creator_id'] == $user_id) {
      $room['other_user'] = [
        'id' => $room['participant_id'],
        'name' => $room['participant_name'],
        'avatar' => $room['participant_avatar']
      ];
    } else {
      $room['other_user'] = [
        'id' => $room['creator_id'],
        'name' => $room['creator_name'],
        'avatar' => $room['creator_avatar']
      ];
    }
    
    // 清理不需要的欄位
    unset($room['creator_name'], $room['creator_avatar'], $room['participant_name'], $room['participant_avatar']);
  }

  // 獲取總數
  $total_count = $db->fetch("
    SELECT COUNT(*) as count
    FROM chat_rooms cr
    WHERE $where_clause
  ", $params);

  Response::success([
    'rooms' => $rooms,
    'total_count' => (int)$total_count['count'],
    'has_more' => count($rooms) >= $limit
  ], 'Rooms retrieved successfully');

} catch (Exception $e) {
  Response::error('Server error: ' . $e->getMessage(), 500);
}
?> 