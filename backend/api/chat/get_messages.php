<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

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

  // Auth - 支援 Header 和 URL 參數
  $token = null;
  
  // 嘗試從 Authorization header 獲取
  $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
  if ($auth_header && preg_match('/Bearer\s+(.*)$/i', $auth_header, $m)) {
    $token = $m[1];
  }
  
  // 如果沒有從 header 獲取到，嘗試從 URL 參數獲取
  if (!$token && isset($_GET['token'])) {
    $token = $_GET['token'];
  }
  
  if (!$token) {
    throw new Exception('Token is required');
  }
  
  $user_id = TokenValidator::validateToken($token);
  if (!$user_id) { 
    throw new Exception('Invalid or expired token'); 
  }
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

  // 驗證用戶是否有權限訪問此聊天室（支援一般聊天室和客服聊天室）
  $room = $db->fetch("
    SELECT 'regular' as source, id, task_id, creator_id, participant_id 
    FROM chat_rooms 
    WHERE id = ? AND (creator_id = ? OR participant_id = ?)
    UNION ALL
    SELECT 'support' as source, id, NULL as task_id, user_id as creator_id, admin_id as participant_id
    FROM support_chat_rooms 
    WHERE id = ? AND (user_id = ? OR admin_id = ?)
    LIMIT 1
  ", [$room_id, $user_id, $user_id, $room_id, $user_id, $user_id]);

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

  // 根據聊天室類型獲取訊息
  if ($room['source'] === 'support') {
    // 客服聊天室訊息
    $messages = $db->fetchAll("
      SELECT 
        scm.id,
        scm.room_id,
        CASE 
          WHEN scm.role = 'user' THEN scm.user_id
          WHEN scm.role = 'admin' THEN scm.admin_id
          ELSE NULL
        END as from_user_id,
        scm.content as message,
        scm.content,
        scm.kind,
        scm.media_url,
        scm.mime_type,
        scm.created_at,
        COALESCE(u.name, a.full_name) as sender_name,
        u.avatar_url as sender_avatar
      FROM support_chat_messages scm
      LEFT JOIN users u ON scm.user_id = u.id AND scm.role = 'user'
      LEFT JOIN admins a ON scm.admin_id = a.id AND scm.role = 'admin'
      WHERE $where_clause
      ORDER BY scm.created_at DESC
      LIMIT ?
    ", array_merge($params, [$limit]));
  } else {
    // 一般聊天室訊息
    $messages = $db->fetchAll("
      SELECT 
        cm.id,
        cm.room_id,
        cm.from_user_id,
        cm.content as message,
        cm.content,
        cm.kind,
        cm.media_url,
        cm.mime_type,
        cm.created_at,
        u.name as sender_name,
        u.avatar_url as sender_avatar
      FROM chat_messages cm
      LEFT JOIN users u ON cm.from_user_id = u.id
      WHERE $where_clause
      ORDER BY cm.created_at DESC
      LIMIT ?
    ", array_merge($params, [$limit]));
  }

  // 反轉順序，讓最新的訊息在最後
  $messages = array_reverse($messages);

  // 格式化時間
  foreach ($messages as &$message) {
    $message['created_at'] = date('Y-m-d H:i:s', strtotime($message['created_at']));
    $message['is_own'] = $message['from_user_id'] == $user_id;
  }

  // 獲取未讀訊息數量（根據聊天室類型使用不同的表）
  if ($room['source'] === 'support') {
    // 客服聊天室未讀訊息計數
    $unread_count = $db->fetch("
      SELECT COUNT(DISTINCT scm.id) as count
      FROM support_chat_messages scm
      LEFT JOIN support_chat_reads scr ON scm.room_id = scr.room_id AND scr.user_id = ?
      WHERE scm.room_id = ? 
      AND scm.role = 'admin'
      AND scm.id > COALESCE(scr.last_read_message_id, 0)
    ", [$user_id, $room_id]);
  } else {
    // 一般聊天室未讀訊息計數
    $unread_count = $db->fetch("
      SELECT COUNT(DISTINCT cm.id) as count
      FROM chat_messages cm
      LEFT JOIN chat_reads cr ON cm.room_id = cr.room_id AND cr.user_id = ?
      WHERE cm.room_id = ? 
      AND cm.from_user_id IS NOT NULL
      AND cm.from_user_id != ? 
      AND cm.id > COALESCE(cr.last_read_message_id, 0)
    ", [$user_id, $room_id, $user_id]);
  }

  // 取得對方的最後已讀訊息 ID（根據聊天室類型使用不同的表）
  if ($room['source'] === 'support') {
    // 客服聊天室：取得管理員的最後已讀
    $opponent_id = $room['participant_id']; // admin_id
    $opponent_read = $db->fetch(
      "SELECT COALESCE(last_read_message_id, 0) AS last_read_message_id FROM support_chat_reads WHERE admin_id = ? AND room_id = ?",
      [$opponent_id, $room_id]
    );
    $opponent_last_read_id = isset($opponent_read['last_read_message_id']) ? (int)$opponent_read['last_read_message_id'] : 0;

    // 也回傳自己最後已讀（客服聊天室）
    $my_read = $db->fetch(
      "SELECT COALESCE(last_read_message_id, 0) AS last_read_message_id FROM support_chat_reads WHERE user_id = ? AND room_id = ?",
      [$user_id, $room_id]
    );
    $my_last_read_id = isset($my_read['last_read_message_id']) ? (int)$my_read['last_read_message_id'] : 0;
  } else {
    // 一般聊天室：取得對方的最後已讀
    $opponent_id = ($room['creator_id'] == $user_id) ? (int)$room['participant_id'] : (int)$room['creator_id'];
    $opponent_read = $db->fetch(
      "SELECT COALESCE(last_read_message_id, 0) AS last_read_message_id FROM chat_reads WHERE user_id = ? AND room_id = ?",
      [$opponent_id, $room_id]
    );
    $opponent_last_read_id = isset($opponent_read['last_read_message_id']) ? (int)$opponent_read['last_read_message_id'] : 0;

    // 也回傳自己最後已讀（一般聊天室）
    $my_read = $db->fetch(
      "SELECT COALESCE(last_read_message_id, 0) AS last_read_message_id FROM chat_reads WHERE user_id = ? AND room_id = ?",
      [$user_id, $room_id]
    );
    $my_last_read_id = isset($my_read['last_read_message_id']) ? (int)$my_read['last_read_message_id'] : 0;
  }

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