<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit(0); }

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';
require_once __DIR__ . '/../../utils/Response.php';


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
    $room_id = $_GET['room_id'] ?? '';
    $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 50;
    $before_id = isset($_GET['before_id']) ? (int)$_GET['before_id'] : null;
  } else {
    $input = json_decode(file_get_contents('php://input'), true) ?? [];
    $room_id = (string)($input['room_id'] ?? '');
    $limit = isset($input['limit']) ? (int)$input['limit'] : 50;
    $before_id = isset($input['before_id']) ? (int)$input['before_id'] : null;
  }

  if ($room_id === '') {
    Response::validationError(['room_id' => 'required']);
  }

  // 驗證用戶是否有權限訪問此聊天室
  $room = $db->fetch("
    SELECT id, task_id, creator_id, participant_id 
    FROM chat_rooms 
    WHERE id = ? AND (creator_id = ? OR participant_id = ?)
    LIMIT 1
  ", [$room_id, $user_id, $user_id]);

  if (!$room) {
    Response::error('Room not found or access denied', 404);
  }

  // 構建查詢條件
  $where_conditions = ['room_id = ?'];
  $params = [$room_id];

  if ($before_id !== null) {
    $where_conditions[] = 'id < ?';
    $params[] = $before_id;
  }

  $where_clause = implode(' AND ', $where_conditions);

  // 獲取訊息
  $messages = $db->fetchAll("
    SELECT 
      cm.id,
      cm.room_id,
      cm.from_user_id,
      cm.content as message,
      cm.created_at,
      u.name as sender_name,
      u.avatar_url as sender_avatar
    FROM chat_messages cm
    LEFT JOIN users u ON cm.from_user_id = u.id
    WHERE $where_clause
    ORDER BY cm.created_at DESC
    LIMIT ?
  ", array_merge($params, [$limit]));

  // 反轉順序，讓最新的訊息在最後
  $messages = array_reverse($messages);

  // 格式化時間
  foreach ($messages as &$message) {
    $message['created_at'] = date('Y-m-d H:i:s', strtotime($message['created_at']));
    $message['is_own'] = $message['from_user_id'] == $user_id;
  }

  // 獲取未讀訊息數量（只計算他人發送的訊息，排除 from_user_id 為 NULL 的訊息，避免重複計算）
  $unread_count = $db->fetch("
    SELECT COUNT(DISTINCT cm.id) as count
    FROM chat_messages cm
    LEFT JOIN chat_reads cr ON cm.room_id = cr.room_id AND cr.user_id = ?
    WHERE cm.room_id = ? 
    AND cm.from_user_id IS NOT NULL
    AND cm.from_user_id != ? 
    AND cm.id > COALESCE(cr.last_read_message_id, 0)
  ", [$user_id, $room_id, $user_id]);

  // 取得對方的最後已讀訊息 ID（用於前端顯示我的訊息是否被已讀）
  $opponent_id = ($room['creator_id'] == $user_id) ? (int)$room['participant_id'] : (int)$room['creator_id'];
  $opponent_read = $db->fetch(
    "SELECT COALESCE(last_read_message_id, 0) AS last_read_message_id FROM chat_reads WHERE user_id = ? AND room_id = ?",
    [$opponent_id, $room_id]
  );
  $opponent_last_read_id = isset($opponent_read['last_read_message_id']) ? (int)$opponent_read['last_read_message_id'] : 0;

  // 也回傳自己最後已讀（可選）
  $my_read = $db->fetch(
    "SELECT COALESCE(last_read_message_id, 0) AS last_read_message_id FROM chat_reads WHERE user_id = ? AND room_id = ?",
    [$user_id, $room_id]
  );
  $my_last_read_id = isset($my_read['last_read_message_id']) ? (int)$my_read['last_read_message_id'] : 0;

  Response::success([
    'messages' => $messages,
    'room_id' => $room_id,
    'unread_count' => (int)$unread_count['count'],
    'has_more' => count($messages) >= $limit,
    'opponent_last_read_message_id' => $opponent_last_read_id,
    'my_last_read_message_id' => $my_last_read_id
  ], 'Messages retrieved successfully');

} catch (Exception $e) {
  Response::error('Server error: ' . $e->getMessage(), 500);
}
?> 