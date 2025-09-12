# 聊天圖片即時傳遞修復總結

## 問題分析

### 原始問題
用戶反映 `/chat/detail` 的圖片傳遞邏輯不是在 socket 上傳成功後直接傳給對方，導致圖片訊息無法即時顯示給對方用戶。

### 根本原因
1. **缺少 Socket 通知機制**：`send_message.php` 在儲存訊息到資料庫後，沒有通過 socket 通知聊天室的其他用戶
2. **通知處理不完整**：`notification_handler.php` 中的 `handleGenericEvent` 函數只記錄事件但不實際發送
3. **端點不一致**：socket 通知的 URL 端點配置不一致
4. **環境變數缺失**：缺少必要的 socket 相關環境變數配置

## 修復方案

### 1. 在 `send_message.php` 中加入 Socket 通知 (✅ 已完成)

**修改位置**：`backend/api/chat/send_message.php`

**新增功能**：
- 加入 `sendSocketNotification` 函數
- 在訊息儲存成功後發送 socket 通知
- 特別記錄圖片訊息的發送

**關鍵程式碼**：
```php
// 發送 Socket 通知給聊天室的其他用戶
$notificationData = [
  'message_id' => $msgId,
  'room_id' => $room_id,
  'from_user_id' => $user_id,
  'content' => $message,
  'kind' => $kind,
  'created_at' => date('Y-m-d H:i:s'),
];

// 發送新訊息通知
sendSocketNotification('message', $notificationData, $room_id);
```

### 2. 修復通知處理器 (✅ 已完成)

**修改位置**：`backend/socket/notification_handler.php`

**修復內容**：
- 修改 `handleGenericEvent` 函數，特殊處理 `message` 事件
- 新增 `handleMessageEvent` 函數，正確處理訊息通知
- 修正 socket 服務器端點 URL（從 `/notify` 改為 `/api/notify`）

**關鍵程式碼**：
```php
function handleMessageEvent($data, $userIds) {
    $roomId = $data['room_id'] ?? null;
    $messageId = $data['message_id'] ?? null;
    $kind = $data['kind'] ?? 'text';
    
    // 發送到 Socket.IO 服務器
    return sendToSocketServer('message', $data);
}
```

### 3. 環境變數配置 (✅ 已完成)

**修改位置**：
- `backend/config/env.example`
- `backend/config/env.development`

**新增配置**：
```bash
SOCKET_URL=http://localhost:3001
SOCKET_TOKEN=default-socket-token
SOCKET_SERVER_URL=http://localhost:3001
SOCKET_SERVER_TOKEN=your-socket-server-token
```

## 技術流程

### 修復後的圖片傳遞流程

1. **前端上傳圖片**：
   ```dart
   // ChatService.uploadAttachment()
   final uploadResult = await ChatService().uploadAttachment(
     roomId: _currentRoomId!,
     image: image,
   );
   ```

2. **前端發送圖片訊息**：
   ```dart
   // ChatService.sendMessage()
   await ChatService().sendMessage(
     roomId: _currentRoomId!,
     message: uploadedUrl ?? '',
     kind: 'image',
   );
   ```

3. **後端處理訊息**：
   ```php
   // send_message.php
   // 1. 儲存訊息到資料庫
   $db->query("INSERT INTO chat_messages (room_id, from_user_id, content, kind) VALUES (?, ?, ?, ?)",
     [$room_id, $user_id, $message, $kind]);
   
   // 2. 發送 Socket 通知
   sendSocketNotification('message', $notificationData, $room_id);
   ```

4. **Socket 通知處理**：
   ```php
   // notification_handler.php
   // 處理 message 事件並轉發到 Socket.IO 服務器
   handleMessageEvent($data, $userIds);
   ```

5. **Socket 服務器廣播**：
   ```javascript
   // server.js
   // 向聊天室用戶廣播新訊息
   io.to(userRoom).emit('message', data);
   ```

6. **前端接收通知**：
   ```dart
   // SocketService
   _socket!.on('message', (data) {
     if (onMessageReceived != null) {
       onMessageReceived!(messageData);
     }
   });
   ```

## 測試驗證

### 測試場景
1. **圖片上傳測試**：
   - 用戶 A 在聊天室發送圖片
   - 驗證用戶 B 能即時收到圖片訊息

2. **文字訊息測試**：
   - 確保修復不影響原有文字訊息功能
   - 驗證所有訊息類型都能正常通知

3. **多用戶測試**：
   - 測試多個用戶同時在線的情況
   - 驗證通知只發送給聊天室相關用戶

### 日誌監控
修復後可以通過以下日誌監控功能：

```bash
# 監控圖片訊息發送
tail -f backend/logs/error.log | grep "Image message sent via socket"

# 監控 Socket 通知處理
tail -f backend/logs/error.log | grep "SocketNotifier"

# 監控 Socket 服務器
tail -f backend/socket/logs/socket.log | grep "message"
```

## 影響範圍

### 修改的文件
1. `backend/api/chat/send_message.php` - 加入 socket 通知
2. `backend/socket/notification_handler.php` - 修復通知處理
3. `backend/config/env.example` - 新增環境變數
4. `backend/config/env.development` - 新增環境變數

### 不受影響的功能
- 圖片上傳功能保持不變
- 訊息儲存到資料庫的邏輯不變
- 前端 UI 和用戶體驗不變
- 其他類型訊息（文字、系統訊息等）的處理

## 部署注意事項

### 環境配置
確保生產環境中設定正確的 socket 相關環境變數：
```bash
SOCKET_URL=https://your-domain.com:3001
SOCKET_TOKEN=your-production-socket-token
SOCKET_SERVER_URL=https://your-domain.com:3001
SOCKET_SERVER_TOKEN=your-production-socket-server-token
```

### Socket 服務器
確保 Socket.IO 服務器正常運行並監聽正確的端口：
```bash
# 啟動 socket 服務器
cd backend/socket
node server.js
```

### 防火牆設定
確保 socket 端口（預設 3001）在防火牆中開放。

## 預期效果

修復完成後，用戶在聊天室發送圖片時：
1. 圖片上傳成功後立即儲存到資料庫
2. 同時通過 socket 即時通知對方用戶
3. 對方用戶無需重新整理即可看到新的圖片訊息
4. 整個過程流暢無延遲，提升用戶體驗

---

**修復完成日期**：2025-09-09  
**影響範圍**：聊天圖片即時傳遞功能  
**預期效果**：圖片訊息即時顯示，無需手動重新整理
