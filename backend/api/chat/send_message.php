<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../config/php84_compatibility.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit(0); }

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../config/env_loader.php';

// 確保環境變數已載入
EnvLoader::load();

/**
 * 發送 Socket 通知
 */
function sendSocketNotification($event, $data, $roomId = null) {
    try {
        // 檢查 cURL 是否可用
        if (!function_exists('curl_init')) {
            error_log("Socket notification error: cURL extension is not available");
            return false;
        }
        
        // 從環境變數讀取 Socket 服務配置
        $socketUrl = $_ENV['SOCKET_URL'] ?? 'http://localhost:3001';
        $socketToken = $_ENV['SOCKET_SERVER_TOKEN'] ?? 'your-socket-server-token';
        
        // 從聊天室獲取用戶ID列表
        $userIds = [];
        if ($roomId) {
            global $db;
            $roomUsers = $db->fetchAll(
                "SELECT creator_id, participant_id FROM chat_rooms WHERE id = ?",
                [$roomId]
            );
            if (!empty($roomUsers)) {
                $room = $roomUsers[0];
                $userIds = [$room['creator_id'], $room['participant_id']];
            }
        }
        
        $notificationData = [
            'event' => $event,
            'data' => $data,
            'userIds' => $userIds
        ];
        
        $ch = curl_init($socketUrl . '/api/notify');
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($notificationData));
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
            'Authorization: Bearer ' . $socketToken
        ]);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 5);
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        curl_close($ch);
        
        if ($error) {
            error_log("Socket notification cURL error: " . $error);
            return false;
        }
        
        if ($httpCode !== 200) {
            error_log("Socket notification HTTP error: " . $httpCode . " - " . $response);
            return false;
        }
        
        error_log("Socket notification sent successfully: " . $event);
        return true;
        
    } catch (Exception $e) {
        error_log("Socket notification error: " . $e->getMessage());
        return false;
    }
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
  $user_id = TokenValidator::validateAuthHeader($auth_header);
  if (!$user_id) { throw new Exception('Invalid or expired token'); }
  $user_id = (int)$user_id;

  $db = Database::getInstance();
  $input = json_decode(file_get_contents('php://input'), true) ?? [];
  // 詳細紀錄請求內容以利除錯
  error_log('send_message payload: ' . json_encode($input, JSON_UNESCAPED_UNICODE));
  
  // 特別記錄圖片訊息
  if (isset($input['kind']) && $input['kind'] === 'image') {
    error_log('🖼️ [send_message] Image message received: room_id=' . ($input['room_id'] ?? 'null') . ', message=' . ($input['message'] ?? 'null'));
  }

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

  // Ensure room exists & fetch related task (支援一般聊天室和客服聊天室)
  $existingRoom = $db->fetch("
    SELECT 'regular' as source, id, task_id, type FROM chat_rooms WHERE id = ?
    UNION ALL
    SELECT 'support' as source, id, NULL as task_id, type FROM support_chat_rooms WHERE id = ?
    LIMIT 1
  ", [$room_id, $room_id]);
  if (!$existingRoom) {
    Response::error('Chat room not found', 404);
  }

  // 移除任務狀態和應徵狀態的限制 - 允許所有狀態進入聊天室

  // 封鎖檢查：基於 user_blocks 表檢查聊天室雙方是否互相封鎖
  if ($existingRoom['source'] === 'support') {
    $roomUsers = $db->fetch("SELECT user_id as creator_id, admin_id as participant_id FROM support_chat_rooms WHERE id = ?", [$room_id]);
  } else {
    $roomUsers = $db->fetch("SELECT creator_id, participant_id FROM chat_rooms WHERE id = ?", [$room_id]);
  }
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

  // Support 聊天室只讀檢查：檢查是否已結案
  if ($existingRoom['type'] === 'support') {
    // 查詢最新的 support_events 狀態
    $supportEventCheck = $db->fetch(
      "SELECT status FROM support_events 
       WHERE support_chat_room_id = ? 
       ORDER BY created_at DESC 
       LIMIT 1",
      [$room_id]
    );
    
    if ($supportEventCheck && $supportEventCheck['status'] === 'resolved') {
      Response::error('Cannot send message: Support case is closed', 403);
    }
  }

  // Insert message（根據聊天室類型插入到不同的表）
  try {
    if ($existingRoom['source'] === 'support') {
      $db->query(
        "INSERT INTO support_chat_messages (room_id, user_id, admin_id, content, kind, role) VALUES (?, ?, NULL, ?, ?, 'user')",
        [$room_id, $user_id, $message, $kind]
      );
    } else {
      $db->query(
        "INSERT INTO chat_messages (room_id, from_user_id, content, kind) VALUES (?, ?, ?, ?)",
        [$room_id, $user_id, $message, $kind]
      );
    }
  } catch (Exception $e) {
    error_log('send_message insert error: ' . $e->getMessage());
    throw $e;
  }
  $row = $db->fetch("SELECT LAST_INSERT_ID() AS id");
  $msgId = (int)$row['id'];

  // Update read of sender to latest
  if ($existingRoom['source'] === 'support') {
    $db->query("INSERT INTO support_chat_reads (user_id, admin_id, role, room_id, last_read_message_id) VALUES (?, NULL, 'user', ?, ?) ON DUPLICATE KEY UPDATE last_read_message_id = VALUES(last_read_message_id)", [$user_id, $room_id, $msgId]);
  } else {
    $db->query("INSERT INTO chat_reads (user_id, room_id, last_read_message_id) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE last_read_message_id = VALUES(last_read_message_id)", [$user_id, $room_id, $msgId]);
  }

  // 發送 Socket 通知給聊天室的其他用戶
  $notificationData = [
    'messageId' => $msgId,
    'roomId' => (string)$room_id,  // 確保為字串格式
    'fromUserId' => $user_id,
    'content' => $message,
    'kind' => $kind,
    'createdAt' => date('Y-m-d H:i:s'),
    // 保持向後兼容
    'message_id' => $msgId,
    'room_id' => $room_id,
    'from_user_id' => $user_id,
    'created_at' => date('Y-m-d H:i:s'),
  ];
  
  // 發送新訊息通知
  error_log("🔔 [send_message] Sending socket notification: room_id=$room_id, message_id=$msgId, kind=$kind");
  $socketResult = sendSocketNotification('message', $notificationData, $room_id);
  
  // 記錄 socket 通知結果
  if ($socketResult) {
    error_log("✅ [send_message] Socket notification sent successfully");
  } else {
    error_log("❌ [send_message] Socket notification failed");
  }
  
  // 如果是圖片訊息，額外記錄
  if ($kind === 'image') {
    error_log("🖼️ [send_message] Image message sent via socket: room_id=$room_id, message_id=$msgId, kind=$kind, socket_success=" . ($socketResult ? 'true' : 'false'));
  }

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

