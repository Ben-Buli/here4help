<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit(0); }

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';
require_once __DIR__ . '/../../utils/Response.php';


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

  $room_id = isset($_POST['room_id']) ? (int)$_POST['room_id'] : 0;
  if ($room_id <= 0) Response::validationError(['room_id' => 'required']);

  // 驗證房間權限（支援一般聊天室和客服聊天室）
  $room = $db->fetch("
    SELECT 'regular' as source, id, task_id, creator_id, participant_id FROM chat_rooms 
    WHERE id = ? AND (creator_id = ? OR participant_id = ?)
    UNION ALL
    SELECT 'support' as source, id, NULL as task_id, user_id as creator_id, admin_id as participant_id 
    FROM support_chat_rooms 
    WHERE id = ? AND (user_id = ? OR admin_id = ?)
    LIMIT 1
  ", [$room_id, $user_id, $user_id, $room_id, $user_id, $user_id]);
  if (!$room) {
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

  // 根據聊天室類型決定儲存位置
  if ($room['source'] === 'support') {
    // 客服聊天室：uploads/support_chat/
    $baseDir = dirname(__DIR__, 2) . '/uploads/support_chat';
    $publicPath = 'uploads/support_chat/' . uniqid('support_') . '.' . $ext;
  } else {
    // 一般聊天室：uploads/chat/
    $baseDir = dirname(__DIR__, 2) . '/uploads/chat';
    $publicPath = 'uploads/chat/' . uniqid('att_') . '.' . $ext;
  }
  
  if (!is_dir($baseDir)) {
    @mkdir($baseDir, 0777, true);
  }
  
  $safeName = basename($publicPath);
  $dest = $baseDir . '/' . $safeName;
  if (!move_uploaded_file($file['tmp_name'], $dest)) {
    Response::error('Failed to move uploaded file', 500);
  }

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

