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

  // Auth
  $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
  if (empty($auth_header) || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $m)) {
    throw new Exception('Authorization header required');
  }
  $payload = validateToken($m[1]);
  if (!$payload) throw new Exception('Invalid or expired token');

  $db = Database::getInstance();
  $input = json_decode(file_get_contents('php://input'), true) ?? [];

  $task_id = isset($input['task_id']) ? (string)$input['task_id'] : '';
  $creator_id = isset($input['creator_id']) ? (int)$input['creator_id'] : 0;
  $participant_id = isset($input['participant_id']) ? (int)$input['participant_id'] : 0;
  $type = isset($input['type']) ? (string)$input['type'] : 'task';

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

  // 查找是否已有房間
  $room = $db->fetch(
    'SELECT id, task_id, creator_id, participant_id, type FROM chat_rooms WHERE task_id = ? AND creator_id = ? AND participant_id = ? AND type = ? LIMIT 1',
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
    $room = [
      'id' => $roomId,
      'task_id' => $task_id,
      'creator_id' => $creator_id,
      'participant_id' => $participant_id,
      'type' => $type,
    ];
  }

  Response::success(['room' => $room], 'Room ensured');
} catch (Exception $e) {
  Response::error('Server error: ' . $e->getMessage(), 500);
}
?>

