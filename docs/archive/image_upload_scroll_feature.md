## 📸 **圖片上傳自動滾動到底部功能**

### 🎯 **功能描述**

在兩個聊天室內頁中實現圖片上傳時自動滾動到底部的功能，提升用戶體驗。

### 🛠️ **修改內容**

#### **1. 一般聊天室 (`chat_detail_page.dart`)**

**修改位置：**
- `_pickAndAddImages()` 方法：圖片開始上傳時滾動
- `_initImageUploadManager()` 中的 `onItemSuccess` 回調：圖片上傳成功後滾動

**具體修改：**

```dart
// 1. 圖片開始上傳時滾動到底部
if (items.isNotEmpty) {
  final files = items.map((item) => item.originalFile).toList();
  await _imageUploadManager!.addImages(files);
  // 圖片開始上傳時滾動到底部
  _scrollToBottom();
}

// 2. 圖片上傳成功後滾動到底部
_imageUploadManager!.onItemSuccess = (item) {
  debugPrint('✅ 圖片上傳成功: ${item.localId}');
  if (mounted) {
    setState(() {
      _pendingImageMessages.removeWhere((msg) => msg.localId == item.localId);
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      _loadChatMessagesFromDatabase();
      // 圖片上傳成功後滾動到底部
      _scrollToBottom();
    });
  }
};
```

#### **2. 客服聊天室 (`support_chat_detail_page.dart`)**

**修改位置：**
- `_sendImageMessage()` 方法：圖片開始上傳時滾動（已存在）
- `_sendImageMessage()` 方法：圖片上傳成功後滾動（新增）

**具體修改：**

```dart
// 1. 圖片開始上傳時滾動到底部（已存在）
if (existingMessageId == null) {
  _scrollToBottom();
}

// 2. 圖片上傳成功後滾動到底部（新增）
Future.delayed(const Duration(milliseconds: 800), () {
  if (mounted) {
    setState(() {
      _uploadingImages.remove(messageId);
    });
    _loadChatMessagesFromDatabase();
    // 圖片上傳成功後滾動到底部
    _scrollToBottom();
  }
});
```

### 🎯 **功能效果**

#### **一般聊天室（圖片托盤系統）**
1. **選擇圖片時**：立即滾動到底部，顯示圖片托盤
2. **上傳成功後**：滾動到底部，顯示上傳的圖片訊息

#### **客服聊天室（直接上傳系統）**
1. **選擇圖片時**：立即滾動到底部，顯示上傳進度
2. **上傳成功後**：滾動到底部，顯示上傳的圖片訊息

### 🔄 **滾動時機**

| 聊天室類型 | 滾動時機 | 滾動原因 |
|-----------|---------|---------|
| 一般聊天室 | 選擇圖片後 | 顯示圖片托盤 |
| 一般聊天室 | 上傳成功後 | 顯示圖片訊息 |
| 客服聊天室 | 選擇圖片後 | 顯示上傳進度 |
| 客服聊天室 | 上傳成功後 | 顯示圖片訊息 |

### 📱 **用戶體驗提升**

1. **即時反饋**：用戶選擇圖片後立即看到上傳狀態
2. **自動定位**：上傳完成後自動滾動到最新訊息
3. **一致性**：兩個聊天室都有相同的滾動行為
4. **流暢性**：避免用戶手動滾動查看上傳結果

### 🧪 **測試建議**

#### **一般聊天室測試**
1. 選擇多張圖片，確認滾動到底部顯示托盤
2. 等待上傳完成，確認滾動到底部顯示圖片訊息
3. 測試上傳失敗情況，確認不會影響滾動

#### **客服聊天室測試**
1. 選擇圖片，確認滾動到底部顯示上傳進度
2. 等待上傳完成，確認滾動到底部顯示圖片訊息
3. 測試重試上傳，確認滾動行為正常
4. 測試上傳失敗，確認不會影響滾動

### ✅ **完成狀態**

- ✅ 一般聊天室：圖片選擇和上傳成功時滾動
- ✅ 客服聊天室：圖片選擇和上傳成功時滾動
- ✅ 保持現有功能不變
- ✅ 提升用戶體驗
