# Block User Socket 通知實作

## 📋 實作概述

在 `backend/api/chat/block_user.php` 中新增完整的 socket 通知發送功能，當用戶進行封鎖/解除封鎖操作時，會即時通知相關聊天室的所有參與者。

## 🚀 實作內容

### **1. Socket 通知函數**

新增 `sendSocketNotification()` 函數：

```php
/**
 * 發送 Socket 通知
 */
function sendSocketNotification($event, $data, $roomId = null) {
    try {
        // 從環境變數讀取 Socket 服務配置
        $socketUrl = $_ENV['SOCKET_URL'] ?? 'http://localhost:3001';
        $socketToken = $_ENV['SOCKET_TOKEN'] ?? 'default-socket-token';
        
        $notificationData = [
            'event' => $event,
            'data' => $data
        ];
        
        // 如果有 roomId，發送到特定房間
        if ($roomId) {
            $notificationData['room'] = $roomId;
        }
        
        // cURL 發送通知到 Socket 服務
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
        
        // 錯誤處理和日誌記錄
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
```

### **2. 封鎖操作通知**

當用戶執行封鎖操作時：

```php
if ($block === 1) {
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
}
```

### **3. 解除封鎖操作通知**

當用戶執行解除封鎖操作時：

```php
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
```

## 🔄 完整流程

### **封鎖操作流程**

1. **用戶 A（creator）點擊封鎖按鈕**
2. **前端發送 POST 請求到 `/backend/api/chat/block_user.php`**
3. **後端執行封鎖邏輯**：
   - 檢查是否已存在封鎖關係
   - 新增封鎖記錄到 `user_blocks` 表
   - 查找相關聊天室
   - 發送 socket 通知到每個聊天室
4. **Socket 服務廣播通知**：
   - 事件：`block_status_update`
   - 數據：包含 room_id, blocked_by_user_id, target_user_id, is_blocked 等
5. **用戶 B（participant）即時接收更新**：
   - 前端 `_onBlockStatusUpdate()` 處理通知
   - 立即更新本地封鎖狀態
   - Alert Bar 顯示封鎖訊息
   - Action Bar 按鈕消失
   - 輸入功能被禁用
   - 顯示 SnackBar 通知

### **Socket 通知數據格式**

#### **封鎖通知**
```json
{
  "event": "block_status_update",
  "data": {
    "room_id": "123",
    "blocked_by_user_id": 456,
    "target_user_id": 789,
    "is_blocked": true,
    "timestamp": 1640995200,
    "action": "block"
  },
  "room": "123"
}
```

#### **解除封鎖通知**
```json
{
  "event": "block_status_update",
  "data": {
    "room_id": "123",
    "unblocked_by_user_id": 456,
    "target_user_id": 789,
    "is_blocked": false,
    "timestamp": 1640995200,
    "action": "unblock"
  },
  "room": "123"
}
```

## ⚙️ 環境配置

需要在 `.env` 檔案中配置 Socket 服務：

```env
# Socket 服務配置
SOCKET_URL=http://localhost:3001
SOCKET_TOKEN=your-secure-socket-token
```

## 🔧 技術特點

### **1. 多聊天室支援**
- 自動查找用戶間的所有聊天室
- 向每個相關聊天室發送通知
- 支援一對多的聊天室關係

### **2. 錯誤處理**
- cURL 錯誤處理
- HTTP 狀態碼檢查
- 異常捕獲和日誌記錄
- 超時設定（連接 3 秒，執行 5 秒）

### **3. 日誌記錄**
- 成功發送日誌
- 錯誤詳細日誌
- 操作統計（影響的聊天室數量）

### **4. 安全性**
- 從環境變數讀取配置
- Bearer Token 驗證
- 輸入驗證和清理

## ✅ 預期效果

實作完成後，當 creator 封鎖 participant 時：

1. ✅ **即時通知**：participant 立即收到封鎖通知
2. ✅ **UI 更新**：Alert Bar 顯示「您已被此用戶封鎖」
3. ✅ **功能禁用**：輸入框、發送按鈕、圖片按鈕全部禁用
4. ✅ **按鈕變化**：Action Bar 中的封鎖相關按鈕消失
5. ✅ **通知提示**：顯示 SnackBar 封鎖通知
6. ✅ **雙向生效**：封鎖者和被封鎖者都無法發送訊息

這個實作確保了封鎖功能的即時性和一致性，大幅提升了使用者體驗。
