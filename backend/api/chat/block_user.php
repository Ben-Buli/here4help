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
        // 從環境變數讀取 Socket 服務配置
        $socketUrl = $_ENV['SOCKET_URL'] ?? 'http://localhost:3001';
        $socketToken = $_ENV['SOCKET_TOKEN'] ?? 'default-socket-token';
        
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
            error_log("Socket notification HTTP error: $httpCode, Response: $response");
            return false;
        }
        
        error_log("Socket notification sent successfully: $event to room $roomId");
        return true;
        
    } catch (Exception $e) {
        error_log("Socket notification exception: " . $e->getMessage());
        return false;
    }
}


try {
  if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
  }

  $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
  if (empty($auth_header) || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $m)) {
    throw new Exception('Authorization header required');
  }
  $user_id = TokenValidator::validateAuthHeader($auth_header);
  if (!$user_id) { throw new Exception('Invalid or expired token'); }
  $user_id = (int)$user_id;

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
    // 檢查是否已經存在封鎖關係（雙向檢查）
    $existingBlock = $db->fetch(
      "SELECT COUNT(*) as block_count FROM user_blocks 
       WHERE (user_id = ? AND target_user_id = ?) 
          OR (user_id = ? AND target_user_id = ?)",
      [$user_id, $target_user_id, $target_user_id, $user_id]
    );
    
    if ($existingBlock && $existingBlock['block_count'] > 0) {
      Response::error('Block relationship already exists between these users', 409);
    }
    
    // 新增封鎖記錄
    $db->query("INSERT INTO user_blocks (user_id, target_user_id) VALUES (?, ?)", [$user_id, $target_user_id]);
    
    // 查找相關的聊天室以發送 socket 通知
    $chatRooms = $db->fetchAll(
      "SELECT id FROM chat_rooms 
       WHERE (creator_id = ? AND participant_id = ?) 
          OR (creator_id = ? AND participant_id = ?)",
      [$user_id, $target_user_id, $target_user_id, $user_id]
    );
    
    // 發送 Socket 通知到所有相關聊天室
    foreach ($chatRooms as $room) {
      $socketData = [
        'room_id' => $room['id'],
        'blocked_by_user_id' => $user_id,
        'target_user_id' => $target_user_id,
        'is_blocked' => true,
        'timestamp' => time(),
        'action' => 'block'
      ];
      
      sendSocketNotification('block_status_update', $socketData, $room['id']);
    }
    
    error_log("Block notification sent for user $user_id blocking $target_user_id in " . count($chatRooms) . " rooms");
    
  } else {
    // 解除封鎖
    $result = $db->query("DELETE FROM user_blocks WHERE user_id = ? AND target_user_id = ?", [$user_id, $target_user_id]);
    
    if ($result === 0) {
      Response::error('No block relationship found to remove', 404);
    }
    
    // 查找相關的聊天室以發送 socket 通知
    $chatRooms = $db->fetchAll(
      "SELECT id FROM chat_rooms 
       WHERE (creator_id = ? AND participant_id = ?) 
          OR (creator_id = ? AND participant_id = ?)",
      [$user_id, $target_user_id, $target_user_id, $user_id]
    );
    
    // 發送 Socket 通知到所有相關聊天室
    foreach ($chatRooms as $room) {
      $socketData = [
        'room_id' => $room['id'],
        'unblocked_by_user_id' => $user_id,
        'target_user_id' => $target_user_id,
        'is_blocked' => false,
        'timestamp' => time(),
        'action' => 'unblock'
      ];
      
      sendSocketNotification('block_status_update', $socketData, $room['id']);
    }
    
    error_log("Unblock notification sent for user $user_id unblocking $target_user_id in " . count($chatRooms) . " rooms");
  }

  Response::success(['target_user_id' => $target_user_id, 'blocked' => $block === 1], 'Block updated');
} catch (Exception $e) {
  Response::error('Server error: ' . $e->getMessage(), 500);
}
?>

