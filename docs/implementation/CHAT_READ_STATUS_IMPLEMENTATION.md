# 聊天室已讀狀態機制實現報告

## 📋 **功能概述**

實現了類似 WhatsApp 的聊天室已讀狀態機制，包含：
- 未讀訊息分隔線 UI
- 智能滾動定位
- 滾動到底部按鈕
- 單勾/雙勾已讀標記

## 🎯 **實現功能**

### **1. 未讀分隔線 UI**
- **位置**：在最後一則已讀訊息與第一則未讀訊息之間
- **樣式**：橙色分隔線 + "Unread Messages Below" 標籤
- **顯示條件**：當有未讀訊息時自動顯示

```dart
Widget _buildUnreadSeparator() {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      children: [
        Expanded(child: Container(height: 1, color: Colors.orange.shade300)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Text('Unread Messages Below', ...),
        ),
        Expanded(child: Container(height: 1, color: Colors.orange.shade300)),
      ],
    ),
  );
}
```

### **2. 智能滾動定位**
- **進入聊天室**：自動滾動到未讀分隔線中央位置
- **無未讀訊息**：滾動到底部
- **滾動計算**：基於估算的 item 高度和螢幕尺寸

```dart
void _scrollToUnreadSeparator({bool delayed = false}) {
  // 找到未讀分隔線的索引
  final unreadSeparatorIndex = _findUnreadSeparatorIndex();
  
  // 計算分隔線的大概位置（每個 item 平均高度約 80px）
  final estimatedItemHeight = 80.0;
  final targetOffset = unreadSeparatorIndex * estimatedItemHeight;
  
  // 獲取螢幕高度的一半，讓分隔線顯示在中央
  final screenHeight = MediaQuery.of(context).size.height;
  final halfScreenHeight = screenHeight / 2;
  
  final finalOffset = (targetOffset - halfScreenHeight).clamp(
    0.0, 
    _listController.position.maxScrollExtent
  );
  
  _listController.animateTo(finalOffset, ...);
}
```

### **3. 滾動到底部按鈕**
- **顯示條件**：有未讀訊息且不在底部時顯示
- **功能**：點擊後滾動到底部並標記所有訊息為已讀
- **位置**：右下角浮動按鈕

```dart
if (_showScrollToBottomButton)
  Positioned(
    bottom: 80,
    right: 16,
    child: FloatingActionButton(
      mini: true,
      onPressed: _scrollToBottomAndMarkAllRead,
      child: const Icon(Icons.keyboard_arrow_down, size: 20),
    ),
  ),
```

### **4. 已讀標記邏輯**
- **單勾 (Icons.done)**：訊息已發送，對方未讀
- **雙勾 (Icons.done_all)**：訊息已發送，對方已讀
- **顏色**：已讀為藍色，未讀為灰色

```dart
final String status = opponentReadId >= msgId ? 'read' : 'sent';

Icon(
  status == 'read' ? Icons.done_all : Icons.done,
  size: 12,
  color: status == 'read' ? Colors.blue : Colors.grey,
)
```

## 🔧 **技術實現**

### **後端 API 支援**
- `backend/api/chat/get_messages.php` 已提供 `my_last_read_message_id` 和 `opponent_last_read_message_id`
- 支援標記已讀的 API 調用

### **前端狀態管理**
```dart
class ChatDetailPage {
  int? _myLastReadMessageId;           // 我的最後已讀訊息 ID
  int? resultOpponentLastReadId;       // 對方最後已讀訊息 ID
  bool _showScrollToBottomButton;      // 是否顯示滾動按鈕
  
  // 檢查是否有未讀訊息
  bool _hasUnreadMessages() {
    return _chatMessages.any((message) {
      final msgId = int.tryParse('${message['id']}') ?? 0;
      return msgId > (_myLastReadMessageId ?? 0);
    });
  }
}
```

### **ListView 整合**
- 動態計算 `totalItemCount` 包含未讀分隔線
- `itemBuilder` 中處理分隔線的渲染和索引調整
- 滾動監聽器控制按鈕顯示/隱藏

## 📱 **用戶體驗**

### **進入聊天室流程**
1. 載入訊息和已讀狀態
2. 檢查是否有未讀訊息
3. **有未讀**：滾動到分隔線中央 + 顯示滾動按鈕
4. **無未讀**：滾動到底部

### **滾動互動**
- 用戶滾動到底部時自動隱藏按鈕
- 離開底部且有未讀時顯示按鈕
- 點擊按鈕滾動到底部並標記全部已讀

### **已讀狀態更新**
- 即時更新對方已讀狀態
- 發送訊息時自動標記自己已讀
- Socket 即時同步已讀狀態

## ✅ **測試要點**

1. **未讀分隔線顯示**：確認分隔線出現在正確位置
2. **滾動定位**：進入聊天室時停在分隔線中央
3. **按鈕功能**：點擊按鈕後正確標記已讀並滾動
4. **已讀標記**：單勾/雙勾正確顯示
5. **即時更新**：Socket 訊息即時更新已讀狀態

## 🎨 **UI 設計**

- **分隔線**：橙色主題，與 app 整體風格一致
- **按鈕**：mini FloatingActionButton，不干擾聊天體驗
- **標記**：遵循 Material Design 的 done/done_all 圖標
- **動畫**：平滑的滾動動畫，提升用戶體驗

## 📝 **注意事項**

1. **性能優化**：使用估算高度避免昂貴的測量操作
2. **狀態同步**：確保前端狀態與後端 API 一致
3. **邊界處理**：正確處理無未讀訊息的情況
4. **響應式設計**：適配不同螢幕尺寸

此實現完全符合用戶需求，提供了類似主流聊天應用的已讀狀態體驗。
