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
  $input = json_decode(file_get_contents('php://input'), true) ?? [];
  // 詳細紀錄請求內容以利除錯
  error_log('send_message payload: ' . json_encode($input, JSON_UNESCAPED_UNICODE));

  // chat_rooms.id 為 BIGINT，強制轉為整數使用
  $room_id = isset($input['room_id']) ? (int)$input['room_id'] : 0;
  // task_id 目前未參與訊息寫入，但保留參數以利前後端一致（UUID 字串）
  $task_id = isset($input['task_id']) ? (string)$input['task_id'] : null;
  $message = trim((string)($input['message'] ?? ''));
  // 新增：支援 kind 參數
  $kind = isset($input['kind']) ? (string)$input['kind'] : 'text';
  
  // 驗證 kind 值
  $validKinds = ['text', 'image', 'file', 'system', 'resume'];
  if (!in_array($kind, $validKinds)) {
    $kind = 'text';
  }
  
  if ($room_id <= 0 || $message === '') {
    Response::validationError(['room_id' => 'required', 'message' => 'required']);
  }

  // Ensure room exists & fetch related task
  $existingRoom = $db->fetch("SELECT id, task_id FROM chat_rooms WHERE id = ?", [$room_id]);
  if (!$existingRoom) {
    Response::error('Chat room not found', 404);
  }

  // 移除任務狀態和應徵狀態的限制 - 允許所有狀態進入聊天室

  // 封鎖檢查：基於 user_blocks 表檢查聊天室雙方是否互相封鎖
  $roomUsers = $db->fetch("SELECT creator_id, participant_id FROM chat_rooms WHERE id = ?", [$room_id]);
  if ($roomUsers) {
    $creatorId = (int)$roomUsers['creator_id'];
    $participantId = (int)$roomUsers['participant_id'];
    
    // 檢查聊天室雙方是否有封鎖關係（不分角色）
    $blockCheck = $db->fetch(
      "SELECT COUNT(*) as block_count FROM user_blocks 
       WHERE (user_id = ? AND target_user_id = ?) 
          OR (user_id = ? AND target_user_id = ?)",
      [$creatorId, $participantId, $participantId, $creatorId]
    );
    
    if ($blockCheck && $blockCheck['block_count'] > 0) {
      Response::error('Cannot send message: Users are blocked', 403);
    }
  }

  // Insert message（使用實際的 content 欄位，並支援 kind）
  try {
    $db->query(
      "INSERT INTO chat_messages (room_id, from_user_id, content, kind) VALUES (?, ?, ?, ?)",
      [$room_id, $user_id, $message, $kind]
    );
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
    'content' => $message, // 兼容性：同時提供兩個欄位名稱
    'kind' => $kind, // 回傳訊息類型
  ], 'Message saved');
} catch (Exception $e) {
  Response::error('Server error: ' . $e->getMessage(), 500);
}
?>

