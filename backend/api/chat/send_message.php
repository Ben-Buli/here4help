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
  $room_id = (string)($input['room_id'] ?? '');
  $task_id = isset($input['task_id']) ? (int)$input['task_id'] : null;
  $message = trim((string)($input['message'] ?? ''));
  if ($room_id === '' || $message === '') {
    Response::validationError(['room_id' => 'required', 'message' => 'required']);
  }

  // Ensure room exists
  $db->query("INSERT IGNORE INTO chat_rooms (id, task_id) VALUES (?, ?)", [$room_id, $task_id]);

  // Insert message
  $db->query("INSERT INTO chat_messages (room_id, from_user_id, message) VALUES (?, ?, ?)", [$room_id, $user_id, $message]);
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

