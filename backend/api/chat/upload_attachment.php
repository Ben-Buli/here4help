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

  $room_id = isset($_POST['room_id']) ? (int)$_POST['room_id'] : 0;
  if ($room_id <= 0) Response::validationError(['room_id' => 'required']);

  // 驗證房間權限
  $room = $db->fetch("SELECT id, task_id, creator_id, participant_id FROM chat_rooms WHERE id = ?", [$room_id]);
  if (!$room || ($room['creator_id'] != $user_id && $room['participant_id'] != $user_id)) {
    Response::error('Room not found or access denied', 404);
  }

  // 檔案檢查
  if (!isset($_FILES['file'])) {
    Response::validationError(['file' => 'required']);
  }
  $file = $_FILES['file'];
  if ($file['error'] !== UPLOAD_ERR_OK) {
    Response::error('Upload error: ' . $file['error'], 400);
  }
  $maxSize = 5 * 1024 * 1024; // 5MB
  if ($file['size'] > $maxSize) {
    Response::error('File too large (max 5MB)', 413);
  }
  $allowed = ['png','jpg','jpeg','gif','webp'];
  $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
  if (!in_array($ext, $allowed)) {
    Response::error('Invalid file type', 422);
  }

  // 儲存位置（開發環境）：backend/uploads/chat/
  $baseDir = dirname(__DIR__, 2) . '/uploads/chat';
  if (!is_dir($baseDir)) {
    @mkdir($baseDir, 0777, true);
  }
  $safeName = uniqid('att_') . '.' . $ext;
  $dest = $baseDir . '/' . $safeName;
  if (!move_uploaded_file($file['tmp_name'], $dest)) {
    Response::error('Failed to move uploaded file', 500);
  }

  // 產出可供前端引用的 URL（相對於 apiBaseUrl）
  $publicPath = '/backend/uploads/chat/' . $safeName;

  Response::success([
    'filename' => $file['name'],
    'saved_as' => $safeName,
    'path' => $publicPath,
    'url' => $publicPath,
  ], 'Uploaded');
} catch (Exception $e) {
  Response::error('Server error: ' . $e->getMessage(), 500);
}
?>

