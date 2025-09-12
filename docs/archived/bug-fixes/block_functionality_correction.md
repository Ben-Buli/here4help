# Block 功能邏輯修正說明

## 📋 修正後的 Block 功能邏輯

根據用戶需求，Block 功能的正確邏輯應該是：

### 🔄 **核心邏輯**
1. **雙方都有 Block 權限**（初始狀態）
2. **一方封鎖後，另一方失去 Block 功能**
3. **雙方聊天室都無法傳遞訊息和圖片**

### 🎯 **實現細節**

#### **Action Bar 按鈕邏輯**
```dart
// 修正後的邏輯
if (!isBlocked) {
  // 沒有任何封鎖關係，顯示 "Block" 按鈕
  actions.add(BlockAction);
} else if (isBlockedByMe) {
  // 我封鎖了對方，顯示 "Blocked" 按鈕，可解除封鎖
  actions.add(UnblockAction);
}
// 如果被對方封鎖（isBlockedByTarget），不顯示任何 Block 相關按鈕
```

#### **狀態判斷**
- `isBlocked`: 任何一方封鎖了另一方（通用封鎖狀態）
- `isBlockedByMe`: 我封鎖了對方
- `isBlockedByTarget`: 對方封鎖了我

#### **按鈕顯示規則**
| 狀態 | 我的按鈕 | 對方的按鈕 | 說明 |
|------|----------|------------|------|
| 無封鎖 | Block | Block | 雙方都可以封鎖 |
| 我封鎖對方 | Blocked (橙色) | 無按鈕 | 只有我可以解除封鎖 |
| 對方封鎖我 | 無按鈕 | Blocked (橙色) | 只有對方可以解除封鎖 |

### 🚫 **輸入功能禁用**

#### **修正前的邏輯**（錯誤）
```dart
final isInputDisabled = _isBlocked ||
    _isBlockedByMe ||
    _isBlockedByTarget ||
    // 其他狀態...
```

#### **修正後的邏輯**（正確）
```dart
final isInputDisabled = _isBlocked || // 任何封鎖狀態都禁用輸入
    // 其他狀態...
```

### 📢 **Alert Bar 訊息**

#### **統一封鎖狀態處理**
```dart
if (_isBlocked) {
  String message;
  if (_isBlockedByMe) {
    message = '您已封鎖此用戶，雙方無法發送訊息。';
  } else if (_isBlockedByTarget) {
    message = '您已被此用戶封鎖，雙方無法發送訊息。';
  } else {
    message = '此聊天室已被限制，雙方無法發送訊息或圖片。';
  }
}
```

### 🔧 **修正的檔案**

1. **`lib/chat/utils/action_bar_config.dart`**
   - 修正 Block 按鈕顯示邏輯
   - 統一使用 `isBlocked` 判斷是否有封鎖關係
   - 只有封鎖方可以看到 "Blocked" 按鈕並解除封鎖

2. **`lib/chat/pages/chat_detail_page.dart`**
   - 簡化輸入禁用邏輯
   - 統一 Alert Bar 封鎖狀態顯示
   - 根據封鎖方向顯示不同訊息

### 🎨 **UI/UX 改進**

#### **按鈕顏色區分**
- **Block 按鈕**: 灰色 (`Color.fromARGB(255, 109, 105, 105)`)
- **Blocked 按鈕**: 橙色 (`Color.fromARGB(255, 255, 152, 0)`)

#### **確認對話框文案**
- **封鎖確認**: "Block this user? This will disable all communication in this chat room."
- **解除封鎖確認**: "Are you sure you want to unblock this user?"

### ✅ **測試場景**

1. **初始狀態**
   - 雙方都看到 "Block" 按鈕
   - 雙方都可以正常發送訊息

2. **A 封鎖 B**
   - A 看到 "Blocked" 按鈕（橙色）
   - B 看不到任何 Block 相關按鈕
   - 雙方都無法發送訊息
   - A 的 Alert Bar: "您已封鎖此用戶，雙方無法發送訊息。"
   - B 的 Alert Bar: "您已被此用戶封鎖，雙方無法發送訊息。"

3. **A 解除封鎖**
   - 恢復到初始狀態
   - 雙方都可以正常發送訊息

### 🔄 **後端需求**

確保後端 API 回傳正確的封鎖狀態：
```json
{
  "is_blocked": true,  // 任何一方封鎖了另一方
  "block_info": {
    "blocked_by_me": true,     // 我是否封鎖了對方
    "blocked_by_target": false // 對方是否封鎖了我
  }
}
```

## 📝 **總結**

修正後的 Block 功能確保：
- ✅ 雙方初始都有封鎖權限
- ✅ 一方封鎖後，另一方失去封鎖功能
- ✅ 只有封鎖方可以解除封鎖
- ✅ 任何封鎖狀態下雙方都無法傳訊息
- ✅ 清楚的視覺回饋和狀態提示

這樣的設計符合用戶需求，避免了雙向封鎖的複雜性，同時確保了功能的直觀性和一致性。
