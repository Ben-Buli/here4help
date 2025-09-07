# Block 功能後端整合與即時同步實現

## 📋 實現概述

根據用戶需求，我們已經完成了 Block 功能的後端檢查邏輯和即時狀態同步機制的實現。

## 🔧 後端 API 更新

### **1. `block_user.php` 重複封鎖檢查**

#### **新增功能**
- **雙向封鎖檢查**: 在執行封鎖前檢查是否已存在封鎖關係
- **防重複封鎖**: 如果任一方已經封鎖了另一方，則返回 409 錯誤
- **Socket 通知**: 封鎖/解除封鎖後自動發送即時通知給雙方用戶

#### **檢查邏輯**
```sql
SELECT COUNT(*) as block_count FROM user_blocks 
WHERE (user_id = ? AND target_user_id = ?) 
   OR (user_id = ? AND target_user_id = ?)
```

#### **錯誤處理**
- **409 Conflict**: "Block relationship already exists between these users"
- **404 Not Found**: "No block relationship found to remove"

### **2. `get_chat_detail_data.php` 詳細狀態回傳**

#### **新增回傳資料**
```json
{
  "is_blocked": true,
  "block_info": {
    "blocked_by_me": true,
    "blocked_by_target": false
  }
}
```

#### **狀態檢查邏輯**
- **我封鎖對方**: `user_id = 當前用戶 AND target_user_id = 對方`
- **對方封鎖我**: `user_id = 對方 AND target_user_id = 當前用戶`
- **通用封鎖狀態**: 任一方向的封鎖都會設置 `is_blocked = true`

## 🔄 即時狀態同步機制

### **1. Socket 事件定義**

#### **封鎖事件**
```json
{
  "event": "block_status_update",
  "data": {
    "blocked_by_user_id": 123,
    "target_user_id": 456,
    "is_blocked": true,
    "timestamp": "2024-01-01T12:00:00Z"
  },
  "userIds": [123, 456]
}
```

#### **解除封鎖事件**
```json
{
  "event": "block_status_update",
  "data": {
    "unblocked_by_user_id": 123,
    "target_user_id": 456,
    "is_blocked": false,
    "timestamp": "2024-01-01T12:00:00Z"
  },
  "userIds": [123, 456]
}
```

### **2. 前端 Socket 監聽**

#### **SocketService 更新**
- 新增 `onBlockStatusUpdate` 監聽器
- 自動解析封鎖狀態更新事件
- 錯誤處理和日誌記錄

#### **ChatDetailPage 整合**
- 監聽封鎖狀態更新事件
- 自動刷新聊天室狀態
- 顯示狀態變化提示訊息

## 🎯 功能流程

### **封鎖流程**
1. **用戶點擊 Block 按鈕**
2. **前端發送封鎖請求**
3. **後端檢查是否已存在封鎖關係**
   - 存在 → 返回 409 錯誤
   - 不存在 → 執行封鎖
4. **後端發送 Socket 通知給雙方**
5. **雙方前端接收通知並刷新狀態**

### **解除封鎖流程**
1. **封鎖方點擊 Blocked 按鈕**
2. **前端發送解除封鎖請求**
3. **後端檢查是否存在封鎖記錄**
   - 不存在 → 返回 404 錯誤
   - 存在 → 執行解除封鎖
4. **後端發送 Socket 通知給雙方**
5. **雙方前端接收通知並刷新狀態**

## 🚫 封鎖狀態處理

### **Action Bar 按鈕邏輯**
| 狀態 | 封鎖方按鈕 | 被封鎖方按鈕 | 說明 |
|------|------------|--------------|------|
| 無封鎖 | Block | Block | 雙方都可以封鎖 |
| A 封鎖 B | Blocked (橙色) | 無按鈕 | 只有 A 可以解除封鎖 |
| B 封鎖 A | 無按鈕 | Blocked (橙色) | 只有 B 可以解除封鎖 |

### **輸入功能禁用**
- 任何封鎖狀態下雙方都無法發送訊息和圖片
- Alert Bar 顯示相應的封鎖狀態訊息

### **Alert Bar 訊息**
- **我封鎖對方**: "You have blocked this user, both parties cannot send messages."
- **被對方封鎖**: "You have been blocked by this user, both parties cannot send messages."
- **通用封鎖**: "This chat room has been restricted, both parties cannot send messages or images."

## 🔧 錯誤處理

### **前端錯誤處理**
- **409 錯誤**: 顯示 "Block relationship already exists" 提示
- **404 錯誤**: 顯示 "No block relationship found to remove" 提示
- **其他錯誤**: 使用通用錯誤處理機制

### **狀態同步**
- 收到錯誤後自動重新載入聊天室狀態
- 確保前端狀態與後端一致

## 📡 即時通知機制

### **Socket 通知流程**
1. **後端執行封鎖/解除封鎖操作**
2. **發送 HTTP 請求到 Socket 服務器**
3. **Socket 服務器廣播事件給指定用戶**
4. **前端接收事件並處理狀態更新**

### **通知範圍**
- **封鎖方**: 收到封鎖確認通知
- **被封鎖方**: 收到被封鎖通知
- **雙方**: 聊天室狀態同步更新

## ✅ 測試場景

### **1. 正常封鎖流程**
- A 封鎖 B → B 立即收到通知並更新狀態
- B 的 Block 按鈕消失，輸入功能禁用
- A 的按鈕變為 "Blocked"，可解除封鎖

### **2. 重複封鎖處理**
- A 封鎖 B 後，B 嘗試封鎖 A → 收到 409 錯誤
- 前端顯示 "Block relationship already exists" 提示
- 自動刷新狀態，B 看到正確的被封鎖狀態

### **3. 解除封鎖流程**
- A 點擊 "Blocked" 按鈕解除封鎖
- B 立即收到通知，恢復正常聊天功能
- 雙方都重新看到 "Block" 按鈕

### **4. 狀態同步**
- 任何封鎖狀態變化都會即時同步給雙方
- 聊天室狀態、Action Bar、Alert Bar 同步更新
- 輸入功能根據封鎖狀態正確啟用/禁用

## 🔧 技術實現要點

### **後端**
- 使用 `user_blocks` 表的 UNIQUE 約束防止重複記錄
- 雙向查詢確保完整的封鎖關係檢查
- cURL 發送 Socket 通知，包含錯誤處理

### **前端**
- Socket 監聽器自動處理封鎖狀態更新
- 錯誤處理區分不同類型的 API 錯誤
- 狀態刷新確保 UI 與後端數據一致

### **Socket 服務**
- 支援自定義事件類型和數據結構
- 批量用戶通知機制
- 連接狀態檢查和錯誤處理

這個實現確保了 Block 功能的完整性、一致性和即時性，提供了良好的用戶體驗和系統穩定性。
