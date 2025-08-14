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
    return $payload;
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
  $user_id = (int)$payload['user_id'];
  // 詳細紀錄請求內容以利除錯
  error_log('send_message payload: ' . json_encode($input, JSON_UNESCAPED_UNICODE));

  // chat_rooms.id 為 BIGINT，強制轉為整數使用
  $room_id = isset($input['room_id']) ? (int)$input['room_id'] : 0;
  // task_id 目前未參與訊息寫入，但保留參數以利前後端一致（UUID 字串）
  $task_id = isset($input['task_id']) ? (string)$input['task_id'] : null;
  $message = trim((string)($input['message'] ?? ''));
  if ($room_id <= 0 || $message === '') {
    Response::validationError(['room_id' => 'required', 'message' => 'required']);
  }

  // Ensure room exists & fetch related task
  $existingRoom = $db->fetch("SELECT id, task_id FROM chat_rooms WHERE id = ?", [$room_id]);
  if (!$existingRoom) {
    Response::error('Chat room not found', 404);
  }

  // Block messaging for completed/closed/canceled/rejected tasks（相容多種欄位）
  if (!empty($existingRoom['task_id'])) {
    try {
      $task = $db->fetch("SELECT * FROM tasks WHERE id = ?", [$existingRoom['task_id']]);
      if ($task) {
        $statusCandidates = [];
        foreach (['status', 'status_code', 'status_display'] as $k) {
          if (isset($task[$k]) && $task[$k] !== '') $statusCandidates[] = strtolower((string)$task[$k]);
        }
        if (isset($task['status_id']) && $task['status_id'] !== null) {
          $statusCandidates[] = 'id:'.(string)$task['status_id'];
        }
        $st = implode(' ', $statusCandidates);
        if (
          strpos($st, 'complete') !== false ||
          strpos($st, 'close') !== false ||
          strpos($st, 'cancel') !== false ||
          strpos($st, 'reject') !== false
        ) {
          Response::error('Messaging disabled for this task status', 403);
        }
      }
    } catch (Exception $e) {
      // 若任務欄位不同步，不阻斷發送（放行）
    }
  }

  // 封鎖檢查：若雙方有任一方封鎖對方，禁止發送（若表不存在則自動建立）
  $opponentIdRow = $db->fetch("SELECT CASE WHEN creator_id = ? THEN participant_id ELSE creator_id END AS opponent_id FROM chat_rooms WHERE id = ?", [$user_id, $room_id]);
  if ($opponentIdRow && isset($opponentIdRow['opponent_id'])) {
    $oppId = (int)$opponentIdRow['opponent_id'];
    // 確保 user_blocks 表存在
    try {
      $db->query("CREATE TABLE IF NOT EXISTS user_blocks (
        id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        user_id BIGINT UNSIGNED NOT NULL,
        target_user_id BIGINT UNSIGNED NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_user_target (user_id, target_user_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");
    } catch (Exception $e) {}

    $blocked = $db->fetch("SELECT 1 FROM user_blocks WHERE (user_id = ? AND target_user_id = ?) OR (user_id = ? AND target_user_id = ?) LIMIT 1", [$user_id, $oppId, $oppId, $user_id]);
    if ($blocked) {
      Response::error('Messaging blocked between users', 403);
    }
  }

  // Insert message（根據實際表結構）
  try {
    // 檢查表結構，確定需要插入哪些欄位
    $columns = $db->fetchAll("SHOW COLUMNS FROM chat_messages");
    $columnNames = array_column($columns, 'Field');
    
    if (in_array('content', $columnNames) && in_array('message', $columnNames)) {
      // 如果兩個欄位都存在，同時插入
      $db->query(
        "INSERT INTO chat_messages (room_id, from_user_id, message, content) VALUES (?, ?, ?, ?)",
        [$room_id, $user_id, $message, $message]
      );
    } elseif (in_array('content', $columnNames)) {
      // 只有 content 欄位
      $db->query(
        "INSERT INTO chat_messages (room_id, from_user_id, content) VALUES (?, ?, ?)",
        [$room_id, $user_id, $message]
      );
    } elseif (in_array('message', $columnNames)) {
      // 只有 message 欄位
      $db->query(
        "INSERT INTO chat_messages (room_id, from_user_id, message) VALUES (?, ?, ?)",
        [$room_id, $user_id, $message]
      );
    } else {
      throw new Exception('No suitable message column found in chat_messages table');
    }
  } catch (Exception $e) {
    error_log('send_message insert error: ' . $e->getMessage());
    throw $e;
  }
  $row = $db->fetch("SELECT LAST_INSERT_ID() AS id");
  $msgId = (int)$row['id'];

  // Update read of sender to latest
  $db->query("INSERT INTO chat_reads (user_id, room_id, last_read_message_id) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE last_read_message_id = VALUES(last_read_message_id)", [$user_id, $room_id, $msgId]);

  Response::success([
    'message_id' => $msgId,
    'room_id' => $room_id,
    'from_user_id' => $user_id,
    'message' => $message,
  ], 'Message saved');
} catch (Exception $e) {
  Response::error('Server error: ' . $e->getMessage(), 500);
}
?>

