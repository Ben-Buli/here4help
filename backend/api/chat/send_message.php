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

  // Auth
  $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
  if (empty($auth_header) || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $m)) {
    throw new Exception('Authorization header required');
  }
  $payload = validateToken($m[1]);
  if (!$payload) throw new Exception('Invalid or expired token');
  $user_id = (int)$payload['user_id'];

  $db = Database::getInstance();
  $input = json_decode(file_get_contents('php://input'), true) ?? [];
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

  // Ensure room exists - 檢查房間是否存在，如果不存在則跳過（房間應該由 ensure_room.php 創建）
  $existingRoom = $db->fetch("SELECT id FROM chat_rooms WHERE id = ?", [$room_id]);
  if (!$existingRoom) {
    Response::error('Chat room not found', 404);
  }

  // Insert message（相容舊欄位 content）
  try {
    // 檢查是否存在 content 欄位（部分舊資料庫尚未移除）
    $hasContentCol = false;
    try {
      $col = $db->fetch("SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chat_messages' AND COLUMN_NAME = 'content' LIMIT 1");
      $hasContentCol = !empty($col);
    } catch (Exception $e) {
      // 忽略檢查失敗，預設為無 content 欄位
    }

    if ($hasContentCol) {
      // 同步寫入 content 與 message，避免 NOT NULL 無預設值造成失敗
      $db->query(
        "INSERT INTO chat_messages (room_id, from_user_id, message, content) VALUES (?, ?, ?, ?)",
        [$room_id, $user_id, $message, $message]
      );
    } else {
      $db->query(
        "INSERT INTO chat_messages (room_id, from_user_id, message) VALUES (?, ?, ?)",
        [$room_id, $user_id, $message]
      );
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

