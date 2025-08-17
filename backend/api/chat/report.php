<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit(0); }

require_once '../../config/database.php';
require_once '../../utils/TokenValidator.php';
require_once '../../utils/Response.php';



try {
  if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
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
  $input = json_decode(file_get_contents('php://input'), true) ?? [];

  $room_id = isset($input['room_id']) ? (int)$input['room_id'] : 0;
  $reason = trim((string)($input['reason'] ?? ''));
  $description = trim((string)($input['description'] ?? ''));
  if ($room_id <= 0) Response::validationError(['room_id' => 'required']);
  if (strlen($reason) === 0) Response::validationError(['reason' => 'required']);
  if (strlen($description) < 10) Response::validationError(['description' => 'min 10 chars']);

  // Access check
  $room = $db->fetch("SELECT id FROM chat_rooms WHERE id = ? AND (creator_id = ? OR participant_id = ?) LIMIT 1", [$room_id, $user_id, $user_id]);
  if (!$room) Response::error('Room not found or access denied', 404);

  // Insert report (simple table-less placeholder: write to log table if exists)
  try {
    // Create table if not exists (lightweight)
    $db->query("CREATE TABLE IF NOT EXISTS chat_reports (
      id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
      room_id BIGINT UNSIGNED NOT NULL,
      reporter_id BIGINT UNSIGNED NOT NULL,
      reason VARCHAR(64) NOT NULL,
      description TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

    $db->query(
      "INSERT INTO chat_reports (room_id, reporter_id, reason, description) VALUES (?, ?, ?, ?)",
      [$room_id, $user_id, $reason, $description]
    );
  } catch (Exception $e) {
    Response::error('Save report failed: ' . $e->getMessage(), 500);
  }

  Response::success(['room_id' => $room_id], 'Report submitted');
} catch (Exception $e) {
  Response::error('Server error: ' . $e->getMessage(), 500);
}
?>

