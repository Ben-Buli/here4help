<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit(0); }

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';
require_once __DIR__ . '/../../utils/Response.php';

// Check if user has already reported a chat room
try {
  if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
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
  
  // Get room_id from query parameters
  $room_id = isset($_GET['room_id']) ? (int)$_GET['room_id'] : 0;
  if ($room_id <= 0) {
    Response::validationError(['room_id' => 'required']);
  }

  // Access check
  $room = $db->fetch("SELECT id FROM chat_rooms WHERE id = ? AND (creator_id = ? OR participant_id = ?) LIMIT 1", [$room_id, $user_id, $user_id]);
  if (!$room) {
    Response::error('Room not found or access denied', 404);
  }

  // Check if user has already reported this room
  try {
    // Check if chat_reports table exists
    $tableExists = $db->fetch("SHOW TABLES LIKE 'chat_reports'");
    
    if (!$tableExists) {
      // Table doesn't exist, user hasn't reported
      Response::success([
        'has_reported' => false,
        'room_id' => $room_id
      ]);
    }

    // Check for existing report
    $existingReport = $db->fetch(
      "SELECT id, created_at FROM chat_reports WHERE room_id = ? AND reporter_id = ? LIMIT 1",
      [$room_id, $user_id]
    );

    if ($existingReport) {
      Response::success([
        'has_reported' => true,
        'room_id' => $room_id,
        'report_id' => $existingReport['id'],
        'reported_at' => $existingReport['created_at']
      ]);
    } else {
      Response::success([
        'has_reported' => false,
        'room_id' => $room_id
      ]);
    }

  } catch (Exception $e) {
    // If there's any error checking the table, assume user hasn't reported
    Response::success([
      'has_reported' => false,
      'room_id' => $room_id
    ]);
  }

} catch (Exception $e) {
  Response::error('Server error: ' . $e->getMessage(), 500);
}
?>
