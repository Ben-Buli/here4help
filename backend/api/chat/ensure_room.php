<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit(0); }

require_once '../../config/database.php';
require_once '../../utils/Response.php';

function validateToken($token) {
  try {
    $decoded = base64_decode($token);
    if ($decoded === false) return null;
    $payload = json_decode($decoded, true);
    if (!$payload || !isset($payload['user_id']) || !isset($payload['exp'])) return null;
    if ($payload['exp'] < time()) return null;
    return $payload; // user_id, email, name, exp
  } catch (Exception $e) { return null; }
}

try {
  if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
  }

  $db = Database::getInstance();
  $input = json_decode(file_get_contents('php://input'), true) ?? [];
  
  // Auth - 支援多種 token 傳遞方式
  $token = null;
  
  // 嘗試從 Authorization header 獲取
  $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
  if (!empty($auth_header) && preg_match('/Bearer\s+(.*)$/i', $auth_header, $m)) {
    $token = $m[1];
  }
  // 備用方案：從 JSON 輸入獲取 token
  elseif (isset($input['token'])) {
    $token = $input['token'];
  }
  
  if (empty($token)) {
    throw new Exception('Authorization header required');
  }
  
  $payload = validateToken($token);
  if (!$payload) throw new Exception('Invalid or expired token');

  $task_id = isset($input['task_id']) ? (string)$input['task_id'] : '';
  $creator_id = isset($input['creator_id']) ? (int)$input['creator_id'] : 0;
  $participant_id = isset($input['participant_id']) ? (int)$input['participant_id'] : 0;
  $type = isset($input['type']) ? (string)$input['type'] : 'application';

  if ($task_id === '' || $creator_id <= 0 || $participant_id <= 0) {
    Response::validationError([
      'task_id' => 'required',
      'creator_id' => 'required',
      'participant_id' => 'required'
    ]);
  }

  // 確認任務存在且 creator_id 正確（可選強化）
  $task = $db->fetch('SELECT id, creator_id FROM tasks WHERE id = ? LIMIT 1', [$task_id]);
  if (!$task) {
    throw new Exception('Task not found');
  }

  // 查找是否已有房間，並同時查詢用戶資料
  $room = $db->fetch(
    'SELECT cr.id, cr.task_id, cr.creator_id, cr.participant_id, cr.type,
            creator.name as creator_name, creator.avatar_url as creator_avatar_url, creator.avatar_url as creator_avatar,
            participant.name as participant_name, participant.avatar_url as participant_avatar_url, participant.avatar_url as participant_avatar
     FROM chat_rooms cr
     LEFT JOIN users creator ON cr.creator_id = creator.id
     LEFT JOIN users participant ON cr.participant_id = participant.id
     WHERE cr.task_id = ? AND cr.creator_id = ? AND cr.participant_id = ? AND cr.type = ? 
     LIMIT 1',
    [$task_id, $creator_id, $participant_id, $type]
  );

  if (!$room) {
    // 建立房間
    $db->query(
      'INSERT INTO chat_rooms (task_id, creator_id, participant_id, type, created_at) VALUES (?, ?, ?, ?, NOW())',
      [$task_id, $creator_id, $participant_id, $type]
    );
    $newIdRow = $db->fetch('SELECT LAST_INSERT_ID() AS id');
    $roomId = (int)$newIdRow['id'];
    
    // 查詢新建房間的完整資料（包含用戶信息）
    $room = $db->fetch(
      'SELECT cr.id, cr.task_id, cr.creator_id, cr.participant_id, cr.type,
              creator.name as creator_name, creator.avatar_url as creator_avatar_url, creator.avatar_url as creator_avatar,
              participant.name as participant_name, participant.avatar_url as participant_avatar_url, participant.avatar_url as participant_avatar
       FROM chat_rooms cr
       LEFT JOIN users creator ON cr.creator_id = creator.id
       LEFT JOIN users participant ON cr.participant_id = participant.id
       WHERE cr.id = ?
       LIMIT 1',
      [$roomId]
    );
  }

  Response::success(['room' => $room], 'Room ensured');
} catch (Exception $e) {
  error_log('ensure_room.php error: ' . $e->getMessage());
  error_log('ensure_room.php trace: ' . $e->getTraceAsString());
  Response::error('Server error: ' . $e->getMessage(), 500);
}
?>


    );
  }

  Response::success(['room' => $room], 'Room ensured');
} catch (Exception $e) {
  error_log('ensure_room.php error: ' . $e->getMessage());
  error_log('ensure_room.php trace: ' . $e->getTraceAsString());
  Response::error('Server error: ' . $e->getMessage(), 500);
}
?>

