# 任務邏輯測試指南

## 修改內容

### 1. **Posted Tasks 分頁**（任務發布者視角）
- ✅ 顯示自己發布的任務卡片
- ✅ 每個任務卡片下方顯示應徵者卡片（0個或多個）
- ✅ 如果任務狀態是 "Open" 且沒有應徵者，顯示提醒字樣

### 2. **My Works 分頁**（任務應徵者/執行者視角）
- ✅ 顯示自己申請的任務卡片
- ✅ 顯示自己作為應徵者的聊天室入口

### 3. **聊天室頁面**
- ✅ **Posted Tasks**：任務發布者相關的任務聊天室
- ✅ **My Works**：任務應徵者/執行者相關的聊天室

## 測試步驟

### 測試 1: Luisa (ID=2) 作為任務發布者

1. **登入 Luisa 帳號** (`luisa@test.com`)
2. **進入聊天頁面**
3. **檢查 Posted Tasks 分頁**：
   - 應該看到 "EasyCard Recharge and MRT Guide" 任務
   - 應該看到 Linda 的應徵者卡片
   - 點擊應徵者卡片進入聊天

### 測試 2: Linda (ID=3) 作為任務應徵者

1. **登入 Linda 帳號** (`linda@test.com`)
2. **進入聊天頁面**
3. **檢查 My Works 分頁**：
   - 應該看到 "EasyCard Recharge and MRT Guide" 任務
   - 應該看到自己的應徵者卡片
   - 點擊應徵者卡片進入與 Luisa 的聊天

### 測試 3: 沒有應徵者的提醒

1. **創建一個新的 Open 狀態任務**
2. **檢查 Posted Tasks 分頁**：
   - 應該看到 "尚未有應徵者投遞申請" 的提醒

## 預期結果

### Luisa 的視角：
- **Posted Tasks**: 看到自己發布的任務 + Linda 的應徵者卡片
- **My Works**: 看到自己申請的任務（如果有）

### Linda 的視角：
- **Posted Tasks**: 看到自己發布的任務（如果有）
- **My Works**: 看到自己申請的任務 + 自己的應徵者卡片

## 技術實現

### 關鍵方法：
1. `_composePostedTasks()`: 篩選當前用戶發布的任務
2. `_composeMyWorks()`: 篩選當前用戶申請的任務
3. `_taskCardWithapplierChatItems()`: 渲染任務卡片和應徵者卡片
4. 沒有應徵者的提醒邏輯：檢查 `_tabController.index == 0 && _displayStatus(task) == 'Open' && visibleapplierChatItems.isEmpty`

### 數據流：
1. 任務數據 → `_composePostedTasks()` / `_composeMyWorks()` → 篩選後的任務列表
2. 應徵者數據 → `_applicationsByTask` → `_convertApplicationsToApplierChatItems()`
3. 渲染 → `_taskCardWithapplierChatItems()` → 任務卡片 + 應徵者卡片 + 提醒 