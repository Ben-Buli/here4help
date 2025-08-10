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
  if ($room_id === '') { Response::validationError(['room_id' => 'required']); }

  // Find latest message id in room
  $row = $db->fetch("SELECT COALESCE(MAX(id),0) AS last_id FROM chat_messages WHERE room_id = ?", [$room_id]);
  $lastId = (int)($row['last_id'] ?? 0);

  $db->query("INSERT INTO chat_reads (user_id, room_id, last_read_message_id) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE last_read_message_id = VALUES(last_read_message_id)", [$user_id, $room_id, $lastId]);

  Response::success(['room_id' => $room_id, 'last_read_message_id' => $lastId], 'Room marked as read');
} catch (Exception $e) {
  Response::error('Server error: ' . $e->getMessage(), 500);
}
?>

