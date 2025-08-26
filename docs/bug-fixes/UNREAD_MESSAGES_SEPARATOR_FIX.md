# "Unread Messages Below" 分隔線顯示邏輯修復報告

## 🐛 問題描述
用戶反映 "Unread Messages Below" 分隔線在錯誤的時機顯示：
- **問題**：當用戶發送訊息後，自己的聊天室中出現了 "Unread Messages Below" 分隔線
- **預期行為**：分隔線應該只在收到對方訊息時顯示，不應該在自己發送訊息後出現

## 🔍 問題根因分析

### 1. **未讀訊息判斷邏輯**
```dart
bool _hasUnreadMessages() {
  if (_myLastReadMessageId == null || _chatMessages.isEmpty) return false;
  
  // 檢查是否有訊息 ID 大於我的最後已讀 ID
  return _chatMessages.any((message) {
    final messageId = message['id'];
    final msgId = (messageId is int) ? messageId : int.tryParse('$messageId') ?? 0;
    return msgId > (_myLastReadMessageId ?? 0);
  });
}
```

### 2. **問題所在**
當用戶發送訊息時：
1. `_sendMessage()` 方法成功發送訊息到後端
2. 新訊息被添加到 `_chatMessages` 列表中
3. **但是 `_myLastReadMessageId` 沒有被更新**
4. 因此 `_hasUnreadMessages()` 認為新發送的訊息是"未讀"的
5. 導致顯示 "Unread Messages Below" 分隔線

## ✅ 修復方案

### 1. **修復文字訊息發送邏輯**
在 `_sendMessage()` 方法中，發送成功後立即更新 `_myLastReadMessageId`：

```dart
// 添加真實訊息
final realMessage = {
  'id': result['message_id'],
  'room_id': result['room_id'],
  'from_user_id': result['from_user_id'] ?? _currentUserId,
  'message': result['message'],
  'content': result['content'] ?? result['message'],
  'kind': result['kind'] ?? 'text',
  'created_at': DateTime.now().toIso8601String(),
};
_chatMessages.add(realMessage);

// 🔧 新增：更新我的最後已讀訊息 ID（我發送的訊息自動標記為已讀）
final messageId = result['message_id'];
if (messageId != null) {
  final msgId = (messageId is int) 
      ? messageId 
      : int.tryParse('$messageId') ?? 0;
  if (msgId > 0) {
    _myLastReadMessageId = msgId;
    debugPrint('✅ 更新我的最後已讀訊息 ID: $_myLastReadMessageId');
  }
}
```

### 2. **修復圖片訊息發送邏輯**
在 `_sendMessageWithImages()` 方法中，圖片上傳成功後也更新 `_myLastReadMessageId`：

```dart
// 1. 先上傳並發送所有圖片
if (_imageTrayItems.isNotEmpty) {
  final uploadedMessageIds = await _imageUploadManager!.startBatchUpload();
  debugPrint('✅ 批量上傳完成，訊息 IDs: $uploadedMessageIds');

  // 🔧 新增：更新我的最後已讀訊息 ID（我發送的圖片訊息自動標記為已讀）
  if (uploadedMessageIds.isNotEmpty) {
    final lastUploadedId = uploadedMessageIds.last;
    final msgId = int.tryParse(lastUploadedId) ?? 0;
    if (msgId > 0 && msgId > (_myLastReadMessageId ?? 0)) {
      setState(() {
        _myLastReadMessageId = msgId;
      });
      debugPrint('✅ 更新我的最後已讀訊息 ID (圖片): $_myLastReadMessageId');
    }
  }

  // 清空托盤
  _imageUploadManager!.clearAll();
}
```

## 🎯 修復邏輯說明

### **核心原則**
- **我發送的訊息 = 自動已讀**：當用戶發送訊息（文字或圖片）時，該訊息應該立即被標記為已讀
- **對方發送的訊息 = 可能未讀**：只有對方發送的訊息才可能產生未讀狀態

### **分隔線顯示條件**
```dart
int _findUnreadSeparatorIndex() {
  if (_myLastReadMessageId == null || _chatMessages.isEmpty) return -1;

  // 找到第一個未讀訊息的位置
  for (int i = 0; i < _chatMessages.length; i++) {
    final messageId = _chatMessages[i]['id'];
    final msgId = (messageId is int) ? messageId : int.tryParse('$messageId') ?? 0;

    if (msgId > (_myLastReadMessageId ?? 0)) {
      // 返回分隔線的索引（在第一個未讀訊息之前）
      return i;
    }
  }

  return -1; // 沒有未讀訊息
}
```

現在當用戶發送訊息後：
1. ✅ 新訊息的 ID 被正確設置到 `_myLastReadMessageId`
2. ✅ `_hasUnreadMessages()` 返回 `false`（因為沒有訊息 ID 大於已讀 ID）
3. ✅ 不會顯示 "Unread Messages Below" 分隔線
4. ✅ 只有收到對方訊息時才可能顯示分隔線

## 📋 測試場景

### ✅ **修復後的正確行為**
1. **用戶發送文字訊息**：
   - 訊息發送成功 → `_myLastReadMessageId` 更新 → 不顯示分隔線 ✅

2. **用戶發送圖片訊息**：
   - 圖片上傳成功 → `_myLastReadMessageId` 更新 → 不顯示分隔線 ✅

3. **收到對方訊息**：
   - 對方訊息 ID > `_myLastReadMessageId` → 顯示分隔線 ✅

4. **點擊滾動到底部**：
   - 調用 `_scrollToBottomAndMarkAllRead()` → 更新 `_myLastReadMessageId` → 分隔線消失 ✅

## 🔧 修改的檔案
- `lib/chat/pages/chat_detail_page.dart`
  - 修復 `_sendMessage()` 方法中的已讀狀態更新
  - 修復 `_sendMessageWithImages()` 方法中的已讀狀態更新

## 🎉 修復效果
- ✅ 用戶發送訊息後不再錯誤顯示 "Unread Messages Below"
- ✅ 分隔線只在收到對方訊息時正確顯示
- ✅ 保持原有的未讀訊息提醒功能
- ✅ 滾動到底部功能正常工作
