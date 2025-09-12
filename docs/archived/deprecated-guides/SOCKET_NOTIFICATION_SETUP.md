# Socket 通知系統設置指南

## 概述

本系統實現了即時任務狀態和應徵狀態更新通知，確保聊天室內的 Action Bar 和狀態顯示能夠即時反映最新的任務狀態。

## 系統架構

### 前端組件
- **SocketService**: 擴展了 Socket.IO 客戶端，添加了任務狀態和應徵狀態監聽器
- **ChatDetailPage**: 監聽狀態變化並自動刷新聊天室數據
- **DynamicActionBar**: 根據最新狀態動態顯示操作按鈕

### 後端組件
- **SocketNotifier**: 統一的通知工具類，負責發送狀態更新事件
- **API 集成**: 在關鍵操作（接受應徵、確認完成等）後發送通知
- **通知處理器**: 接收並轉發通知到 Socket.IO 服務器

## 功能特點

### ✅ 即時狀態同步
- 任務狀態變化時自動通知相關用戶
- 應徵狀態變化時即時更新 Action Bar
- 支持多用戶同時接收通知

### ✅ 智能過濾
- 只通知相關聊天室的用戶
- 避免不必要的通知和數據刷新
- 支持按用戶ID精確推送

### ✅ 錯誤處理
- Socket 連接失敗時優雅降級
- 通知發送失敗不影響主流程
- 詳細的錯誤日誌記錄

## 設置步驟

### 1. 環境變數配置

在 `.env` 文件中添加以下配置：

```env
# Socket.IO 服務器配置
SOCKET_SERVER_URL=http://localhost:3000
SOCKET_SERVER_TOKEN=your-socket-server-token
```

### 2. 前端設置

#### SocketService 擴展
```dart
// 已添加新的監聽器
Function(Map<String, dynamic>)? onTaskStatusUpdate;
Function(Map<String, dynamic>)? onApplicationStatusUpdate;

// 已添加事件監聽
_socket!.on('task_status_update', (data) => { ... });
_socket!.on('application_status_update', (data) => { ... });
```

#### ChatDetailPage 監聽器設置
```dart
// 在 _initializeChat() 中設置監聽器
_socketService.onTaskStatusUpdate = _onTaskStatusUpdate;
_socketService.onApplicationStatusUpdate = _onApplicationStatusUpdate;

// 實現監聽器方法
void _onTaskStatusUpdate(Map<String, dynamic> data) {
  // 檢查是否為當前聊天室
  if (data['room_id'] == _currentRoomId || data['task_id'] == _task?['id']) {
    _initializeChat(); // 重新載入數據
  }
}
```

### 3. 後端設置

#### SocketNotifier 工具類
```php
// 已創建 backend/utils/socket_notifier.php
// 提供統一的通知接口
$socketNotifier = SocketNotifier::getInstance();
$socketNotifier->notifyTaskStatusUpdate($taskId, $roomId, $statusData, $userIds);
```

#### API 集成
```php
// 在關鍵 API 中添加通知
// 例如：backend/api/tasks/applications/accept.php
// 例如：backend/api/tasks/confirm_completion.php

// 在操作完成後發送通知
$socketNotifier->notifyTaskStatusUpdate($task_id, $roomId, $statusData, $userIds);
$socketNotifier->notifyApplicationStatusUpdate($task_id, $roomId, 'accepted', $userIds);
```

### 4. Socket.IO 服務器設置

#### 通知端點
```php
// 已創建 backend/socket/notification_handler.php
// 處理來自後端的通知請求
```

#### 事件轉發
在實際的 Socket.IO 服務器中，需要實現以下邏輯：

```javascript
// 接收來自 PHP 的通知
app.post('/api/notify', (req, res) => {
  const { event, data, userIds } = req.body;
  
  // 驗證 token
  if (req.headers.authorization !== `Bearer ${process.env.SOCKET_SERVER_TOKEN}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  // 向指定用戶發送事件
  userIds.forEach(userId => {
    const userSocket = getUserSocket(userId);
    if (userSocket) {
      userSocket.emit(event, data);
    }
  });
  
  res.json({ success: true });
});
```

## 使用方式

### 前端監聽狀態變化

```dart
// 在 ChatDetailPage 中
void _onTaskStatusUpdate(Map<String, dynamic> data) {
  debugPrint('📋 Task status update received: $data');
  
  // 檢查是否為當前聊天室
  final roomId = data['room_id']?.toString();
  final taskId = data['task_id']?.toString();
  
  if (roomId == _currentRoomId || taskId == _task?['id']?.toString()) {
    debugPrint('🔄 Refreshing chat data due to task status update');
    _initializeChat(); // 重新載入聊天室數據
  }
}
```

### 後端發送通知

```php
// 在任務狀態變化後
$socketNotifier = SocketNotifier::getInstance();
$userIds = $socketNotifier->getTaskUserIds($task_id);
$roomId = $room['id'];

$statusData = [
  'code' => 'completed',
  'display_name' => 'Completed',
  'progress_ratio' => 1.0
];

$socketNotifier->notifyTaskStatusUpdate($task_id, $roomId, $statusData, $userIds);
```

## 支持的事件類型

### 任務狀態更新
- **事件**: `task_status_update`
- **數據格式**:
```json
{
  "task_id": "123",
  "room_id": "456",
  "status": {
    "code": "completed",
    "display_name": "Completed",
    "progress_ratio": 1.0
  },
  "timestamp": "2024-01-01 12:00:00"
}
```

### 應徵狀態更新
- **事件**: `application_status_update`
- **數據格式**:
```json
{
  "task_id": "123",
  "room_id": "456",
  "application_status": "accepted",
  "timestamp": "2024-01-01 12:00:00"
}
```

## 故障排除

### 常見問題

1. **Socket 連接失敗**
   - 檢查 Socket.IO 服務器是否運行
   - 確認 URL 和端口配置正確
   - 檢查防火牆設置

2. **通知未收到**
   - 確認用戶已加入對應的聊天室
   - 檢查用戶ID是否正確
   - 查看服務器日誌

3. **狀態未更新**
   - 確認 API 中已添加通知代碼
   - 檢查 SocketNotifier 是否正確初始化
   - 查看錯誤日誌

### 調試方法

1. **前端調試**
```dart
// 在 ChatDetailPage 中添加調試日誌
debugPrint('🔍 Socket connected: ${_socketService.isConnected}');
debugPrint('🔍 Current room: $_currentRoomId');
```

2. **後端調試**
```php
// 在 API 中添加調試日誌
error_log("[API] Task status updated: $task_id");
error_log("[API] Sending notification to users: " . implode(',', $userIds));
```

## 性能考慮

1. **批量通知**: 對於多個用戶，使用批量通知減少網絡請求
2. **連接池**: 使用連接池管理 Socket.IO 連接
3. **錯誤重試**: 實現通知發送失敗的重試機制
4. **緩存**: 緩存用戶連接狀態，避免重複查詢

## 安全考慮

1. **Token 驗證**: 所有通知請求都需要有效的 token
2. **用戶權限**: 只向有權限的用戶發送通知
3. **數據驗證**: 驗證所有輸入數據的格式和內容
4. **日誌記錄**: 記錄所有通知發送和接收的日誌
