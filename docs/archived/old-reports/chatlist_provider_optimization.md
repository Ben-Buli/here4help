# ChatListProvider 快照更新優化

## 🔍 **問題描述**

在 Block/Unblock 功能執行時，發現 `ChatListProvider.replaceUnreadByRoom()` 方法被頻繁調用，導致不必要的快照更新和事件廣播。

### **問題表現**
```
🧹 [ChatListProvider] 以快照覆蓋未讀數: 1 個房間
📡 [ChatListProvider] 發出事件: room_unread_replace
```
這個日誌在短時間內重複出現多次，特別是在 Action Bar 狀態切換時。

## 🎯 **根本原因**

### **1. 缺少變化檢測**
原始的 `replaceUnreadByRoom` 方法沒有檢查數據是否真的有變化，每次調用都會：
- 清空 `_unreadByRoom`
- 重新設置所有數據
- 無條件廣播 `room_unread_replace` 事件

### **2. 過度更新**
即使未讀數據沒有任何變化，也會觸發：
- UI 重新渲染
- 事件監聽器回調
- 不必要的性能開銷

## 🔧 **優化方案**

### **實施的改進**

#### **1. 智能變化檢測**
```dart
// 檢查房間數量是否變化
if (_unreadByRoom.length != normalizedSnapshot.length) {
  hasChanges = true;
}

// 檢查每個房間的未讀數是否變化
for (final entry in normalizedSnapshot.entries) {
  final roomId = entry.key;
  final newCount = entry.value;
  final oldCount = _unreadByRoom[roomId] ?? 0;
  
  if (oldCount != newCount) {
    hasChanges = true;
    break;
  }
}

// 檢查是否有房間被移除
for (final roomId in _unreadByRoom.keys) {
  if (!normalizedSnapshot.containsKey(roomId)) {
    hasChanges = true;
    break;
  }
}
```

#### **2. 條件性更新**
```dart
// 只有在有變化時才更新
if (hasChanges) {
  debugPrint('✅ [ChatListProvider] 檢測到變化，執行快照覆蓋');
  _unreadByRoom
    ..clear()
    ..addAll(normalizedSnapshot);
  _emit('room_unread_replace');
} else {
  debugPrint('⏭️ [ChatListProvider] 未檢測到變化，跳過快照覆蓋');
}
```

#### **3. 詳細的調試日誌**
- 房間數量變化追蹤
- 個別房間未讀數變化追蹤
- 房間移除檢測
- 跳過更新的明確日誌

## 📊 **預期效果**

### **性能改善**
1. **減少不必要的 UI 更新**：只在數據真正變化時才觸發重新渲染
2. **降低事件廣播頻率**：避免重複的 `room_unread_replace` 事件
3. **提升響應性**：減少無效的計算和處理

### **用戶體驗改善**
1. **更流暢的 Action Bar 切換**：Block/Unblock 操作不會觸發多餘的更新
2. **減少視覺閃爍**：避免不必要的 UI 重新渲染
3. **更穩定的狀態管理**：確保狀態變化的一致性

## 🧪 **測試建議**

### **測試場景**
1. **Block/Unblock 操作**：確認不會產生重複的快照更新日誌
2. **正常聊天操作**：確認未讀數正常更新
3. **多房間場景**：確認批量更新的效率

### **監控指標**
- `room_unread_replace` 事件的觸發頻率
- Action Bar 狀態切換的響應時間
- 整體 UI 流暢度

## 📝 **實施日期**
2025-01-08

## ✅ **狀態**
已完成 - 優化已實施並準備測試
