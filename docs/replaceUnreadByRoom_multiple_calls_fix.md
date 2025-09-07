# replaceUnreadByRoom 多次呼叫問題修復

## 📋 問題描述

從 MyWorksWidget 進入 ChatDetailPage 時，`replaceUnreadByRoom()` 方法被多次觸發，造成不必要的重複處理。

## 🔍 原因分析

### **多重監聽導致重複呼叫**

1. **NotificationCenter 全域自動同步** (第445行)
   ```dart
   _s3 = _service.observeUnreadByRoom().listen((byRoom) {
     _byRoomForwarder.add(byRoom);
     // 自動呼叫 replaceUnreadByRoom
     final provider = ChatListProvider.instance;
     provider?.replaceUnreadByRoom(byRoom); // ← 第一次呼叫
   });
   ```

2. **MyWorksWidget 額外監聽** (第271行)
   ```dart
   _unreadSub = NotificationCenter().byRoomStream.listen((map) {
     // ...
     safeProvider.replaceUnreadByRoom(map); // ← 第二次呼叫
   });
   ```

3. **PostedTasksWidget 額外監聽** (第319行)
   ```dart
   _unreadSub = NotificationCenter().byRoomStream.listen((unreadData) {
     // ...
     provider?.replaceUnreadByRoom(unreadData); // ← 第三次呼叫
   });
   ```

### **觸發時機**

```
用戶點擊 MyWorksWidget 任務卡片
    ↓
ChatNavigationService.ensureRoomAndNavigate()
    ↓
ChatDetailPage.initState() → _initializeChat()
    ↓
_setupSocket() → Socket 連接並加入房間
    ↓
Socket 觸發未讀數據刷新
    ↓
NotificationCenter.byRoomStream 發出事件
    ↓
三個監聽器同時觸發 → replaceUnreadByRoom() 被呼叫 3 次
```

## ✅ 解決方案

### **方案一：移除重複監聽（已實作）**

移除 MyWorksWidget 和 PostedTasksWidget 中的重複 `replaceUnreadByRoom()` 呼叫，因為 NotificationCenter 已經自動處理。

#### **修改內容**

1. **MyWorksWidget.dart**
   ```dart
   // 修改前：重複呼叫 replaceUnreadByRoom
   _unreadSub = NotificationCenter().byRoomStream.listen((map) {
     // ...
     safeProvider.replaceUnreadByRoom(map); // ← 移除
     // ...
   });

   // 修改後：只更新 Tab 標記
   _unreadSub = NotificationCenter().byRoomStream.listen((map) {
     // 只更新 Tab 未讀標記，不重複呼叫 replaceUnreadByRoom
     WidgetsBinding.instance.addPostFrameCallback((_) {
       if (!mounted) return;
       _updateMyWorksTabUnreadFlag();
     });
   });
   ```

2. **PostedTasksWidget.dart**
   ```dart
   // 修改前：重複呼叫 replaceUnreadByRoom
   _unreadSub = NotificationCenter().byRoomStream.listen((unreadData) {
     // ...
     provider?.replaceUnreadByRoom(unreadData); // ← 移除
     // ...
   });

   // 修改後：只更新 Tab 標記
   _unreadSub = NotificationCenter().byRoomStream.listen((unreadData) {
     // 只更新 Tab 未讀標記，不重複呼叫 replaceUnreadByRoom
     Future.delayed(const Duration(milliseconds: 100), () {
       if (!mounted) return;
       _updatePostedTabUnreadFlag();
     });
   });
   ```

3. **簡化 _ensureUnreadDataLoaded() 方法**
   ```dart
   // 修改前：手動呼叫 replaceUnreadByRoom
   Future<void> _ensureUnreadDataLoaded() async {
     await NotificationCenter().waitForUnreadData();
     provider?.replaceUnreadByRoom(unreadData); // ← 移除
   }

   // 修改後：依賴自動同步
   Future<void> _ensureUnreadDataLoaded() async {
     await NotificationCenter().waitForUnreadData();
     // NotificationCenter 會自動同步到 Provider，無需手動呼叫
   }
   ```

## 🎯 修復效果

### **修復前**
```
NotificationCenter.byRoomStream 發出事件
    ↓
1. NotificationCenter 自動呼叫 replaceUnreadByRoom() 
2. MyWorksWidget 監聽器呼叫 replaceUnreadByRoom()     
3. PostedTasksWidget 監聽器呼叫 replaceUnreadByRoom() 
    ↓
同一個事件觸發 3 次相同的方法呼叫 ❌
```

### **修復後**
```
NotificationCenter.byRoomStream 發出事件
    ↓
1. NotificationCenter 自動呼叫 replaceUnreadByRoom() ✅
2. MyWorksWidget 監聽器只更新 Tab 標記 ✅
3. PostedTasksWidget 監聽器只更新 Tab 標記 ✅
    ↓
只有一次 replaceUnreadByRoom() 呼叫，其他組件各司其職 ✅
```

## 🔧 技術優勢

1. **效能提升**：減少 66% 的重複處理
2. **邏輯清晰**：單一職責原則，NotificationCenter 負責數據同步，Widget 負責 UI 更新
3. **維護性佳**：避免多處重複邏輯，降低維護成本
4. **穩定性高**：減少競態條件和重複更新的風險

## 📝 其他可選方案

### **方案二：移除 NotificationCenter 自動同步**
```dart
// 在 NotificationCenter 中移除自動呼叫
_s3 = _service.observeUnreadByRoom().listen((byRoom) {
  _byRoomForwarder.add(byRoom);
  // 移除自動同步，讓各組件自行決定
});
```

### **方案三：添加防重複機制**
```dart
// 在 replaceUnreadByRoom 中添加時間戳檢查
void replaceUnreadByRoom(Map<String, int> snapshot) {
  final now = DateTime.now().millisecondsSinceEpoch;
  if (now - _lastReplaceTime < 100) return; // 防重複
  _lastReplaceTime = now;
  // 原有邏輯...
}
```

## ✅ 結論

已成功實作方案一，移除了重複的 `replaceUnreadByRoom()` 呼叫，保持了 NotificationCenter 的自動同步機制，同時讓各 Widget 專注於自己的 UI 更新邏輯。這樣既解決了多次呼叫的問題，又保持了架構的清晰性和可維護性。
