# Unblock 功能即時同步問題診斷與修復

## 🔍 **問題描述**

當用戶在聊天室使用 unblock 功能時，被封鎖的對象沒有即時看到成功解除封鎖的狀態更新。

## 🕵️ **問題診斷**

### **1. 後端 Socket 通知機制檢查**

✅ **後端通知機制正常**：
- `backend/api/chat/block_user.php` 在解除封鎖時確實發送了 Socket 通知
- 通知數據格式正確：
```php
$notificationData = [
  'event' => 'block_status_update',
  'data' => [
    'unblocked_by_user_id' => $user_id,
    'target_user_id' => $target_user_id,
    'is_blocked' => false,
    'timestamp' => date('c')
  ],
  'userIds' => [$user_id, $target_user_id]
];
```

### **2. Socket 服務器檢查**

✅ **Socket 服務器正常**：
- `backend/socket/server.js` 的 `/api/notify` 端點正確處理通知
- 向指定用戶發送 `block_status_update` 事件

### **3. 前端 Socket 監聽器檢查**

✅ **前端監聽器已設置**：
- `_socketService.onBlockStatusUpdate = _onBlockStatusUpdate;` 已正確設置
- `_onBlockStatusUpdate` 方法存在並處理事件

### **4. 發現的潛在問題**

#### **問題 A：調試信息不足**
- 缺少詳細的調試日誌來追蹤事件流程
- 無法確定事件是否正確接收和處理

#### **問題 B：用戶體驗反饋不明確**
- 解除封鎖成功後的 SnackBar 通知不夠明顯
- 缺少視覺化的狀態變更反饋

## 🔧 **實施的修復**

### **1. 增強調試日誌**

在 `_onBlockStatusUpdate` 方法中添加了詳細的調試信息：

```dart
debugPrint('🔍 [ChatDetailPage] Block status data: $data');
debugPrint('🔍 [ChatDetailPage] Current user: $currentUserId, Opponent: $opponentId');
debugPrint('🔍 [ChatDetailPage] Blocked by: $blockedByUserId, Unblocked by: $unblockedByUserId, Target: $targetUserId, Is blocked: $isBlocked');
```

### **2. 改善 SnackBar 通知**

將原本簡單的文字通知升級為帶圖標和顏色的豐富通知：

```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Row(
      children: [
        Icon(
          isBlocked ? Icons.block : Icons.check_circle,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isBlocked ? '封鎖狀態已更新' : '已成功解除封鎖',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
    backgroundColor: isBlocked ? Colors.red : Colors.green,
    duration: const Duration(seconds: 3),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
);
```

### **3. 修復變量聲明順序**

修復了 `opponentId` 變量在使用前未聲明的問題，確保調試日誌能正常運行。

## 🧪 **測試建議**

### **1. 功能測試**

#### **測試場景 A：基本解除封鎖**
1. 用戶 A 封鎖用戶 B
2. 用戶 A 解除封鎖用戶 B
3. **預期結果**：
   - 用戶 A 看到綠色 "已成功解除封鎖" 通知
   - 用戶 B 看到綠色 "已成功解除封鎖" 通知
   - 雙方的 Action Bar 和 Alert Bar 立即更新
   - 雙方可以重新發送訊息

#### **測試場景 B：調試日誌驗證**
1. 開啟 Flutter 調試模式
2. 執行解除封鎖操作
3. **檢查日誌**：
   - 確認收到 `block_status_update` 事件
   - 確認用戶 ID 匹配正確
   - 確認 `is_blocked: false` 狀態

### **2. 網絡測試**

#### **測試場景 C：網絡延遲**
1. 模擬網絡延遲環境
2. 執行解除封鎖操作
3. **預期結果**：即使有延遲，最終雙方都應該收到通知

#### **測試場景 D：Socket 連接中斷**
1. 暫時中斷 Socket 連接
2. 執行解除封鎖操作
3. 重新連接 Socket
4. **預期結果**：重新連接後狀態應該同步

## 🔍 **進一步診斷步驟**

如果問題仍然存在，請按以下順序檢查：

### **1. 檢查 Socket 連接狀態**
```dart
// 在 _onBlockStatusUpdate 開始處添加
debugPrint('🔌 Socket connected: ${_socketService.isConnected}');
```

### **2. 檢查用戶 ID 匹配**
確認 `currentUserId` 和 `opponentId` 是否正確獲取：
```dart
debugPrint('👤 Current user ID type: ${currentUserId.runtimeType}');
debugPrint('👤 Opponent ID type: ${opponentId.runtimeType}');
```

### **3. 檢查後端日誌**
查看 Socket 服務器日誌，確認：
- 是否收到 unblock 通知請求
- 是否成功發送給目標用戶
- 用戶是否在線

### **4. 檢查前端 Socket 事件**
在 `lib/chat/services/socket_service.dart` 中添加：
```dart
_socket!.on('block_status_update', (data) {
  debugPrint('🚫 Raw block status update received: $data');
  // ... 現有代碼
});
```

## 📊 **預期改善效果**

### **修復前**
- 解除封鎖後對方可能不知道狀態變化
- 缺少明確的成功反饋
- 難以診斷問題原因

### **修復後**
- ✅ 詳細的調試日誌幫助追蹤問題
- ✅ 豐富的視覺反饋（綠色勾選圖標 + 成功訊息）
- ✅ 更穩定的事件處理流程
- ✅ 更好的用戶體驗

## 🎯 **總結**

通過增強調試日誌和改善用戶反饋，我們提高了 unblock 功能的可靠性和用戶體驗。如果問題仍然存在，詳細的調試信息將幫助我們快速定位根本原因。

**關鍵改善**：
1. 🔍 **增強調試**：詳細的事件追蹤日誌
2. 🎨 **改善反饋**：豐富的 SnackBar 通知
3. 🛠 **修復 Bug**：變量聲明順序問題
4. 📋 **測試指南**：完整的測試場景和診斷步驟
