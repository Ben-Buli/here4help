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

  $input = json_decode(file_get_contents('php://input'), true) ?? [];
  $target_user_id = isset($input['target_user_id']) ? (int)$input['target_user_id'] : 0;
  $block = isset($input['block']) ? (int)$input['block'] : 1;
  if ($target_user_id <= 0) Response::validationError(['target_user_id' => 'required']);
  if ($target_user_id === $user_id) Response::validationError(['target_user_id' => 'cannot block yourself']);

  $db = Database::getInstance();

  // Create table if not exists
  $db->query("CREATE TABLE IF NOT EXISTS user_blocks (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    target_user_id BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_user_target (user_id, target_user_id)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

  if ($block === 1) {
    $db->query("INSERT INTO user_blocks (user_id, target_user_id) VALUES (?, ?) ON DUPLICATE KEY UPDATE created_at = CURRENT_TIMESTAMP", [$user_id, $target_user_id]);
  } else {
    $db->query("DELETE FROM user_blocks WHERE user_id = ? AND target_user_id = ?", [$user_id, $target_user_id]);
  }

  Response::success(['target_user_id' => $target_user_id, 'blocked' => $block === 1], 'Block updated');
} catch (Exception $e) {
  Response::error('Server error: ' . $e->getMessage(), 500);
}
?>

