<?php
require_once 'config/database.php';
require_once 'utils/Response.php';

// 模擬測試參數
$_GET['room_id'] = '69';
$_GET['token'] = 'eyJ1c2VyX2lkIjoyLCJleHAiOjE3NTUxNTIwMDB9'; // 模擬 token
$_SERVER['REQUEST_METHOD'] = 'GET';

echo "=== 調試 get_messages.php ===\n";

try {
  // 模擬 token 驗證
  $token = $_GET['token'];
  echo "Token: $token\n";
  
  // 簡單的 base64 解碼測試
  $decoded = base64_decode($token);
  echo "Decoded: $decoded\n";
  
  $payload = json_decode($decoded, true);
  echo "Payload: " . print_r($payload, true) . "\n";
  
  if ($payload && isset($payload['user_id'])) {
    $user_id = (int)$payload['user_id'];
    echo "User ID: $user_id\n";
    
    $db = Database::getInstance();
    
    // 檢查房間是否存在
    $room = $db->fetch("
      SELECT id, task_id, creator_id, participant_id 
      FROM chat_rooms 
      WHERE id = ?
      LIMIT 1
    ", [$_GET['room_id']]);
    
    echo "Room: " . print_r($room, true) . "\n";
    
    if ($room) {
      // 檢查權限
      $hasAccess = ($room['creator_id'] == $user_id || $room['participant_id'] == $user_id);
      echo "Has access: " . ($hasAccess ? 'YES' : 'NO') . "\n";
      
      if ($hasAccess) {
        // 獲取訊息
        $messages = $db->fetchAll("
          SELECT 
            cm.id,
            cm.room_id,
            cm.from_user_id,
            cm.message,
            cm.created_at
          FROM chat_messages cm
          WHERE cm.room_id = ?
          ORDER BY cm.created_at DESC
          LIMIT 10
        ", [$_GET['room_id']]);
        
        echo "Messages count: " . count($messages) . "\n";
        echo "First 3 messages:\n";
        foreach (array_slice($messages, 0, 3) as $msg) {
          echo "  - ID: {$msg['id']}, From: {$msg['from_user_id']}, Message: {$msg['message']}\n";
        }
      }
    }
  }
  
} catch (Exception $e) {
  echo "Error: " . $e->getMessage() . "\n";
}

echo "=== 調試完成 ===\n";
?> 