# 客服聊天室模組需求說明

## 概述
客服聊天室模組提供使用者與管理員之間的客服支援功能，透過聊天室介面進行問題諮詢和處理。

## 資料表結構

### 核心資料表
- `support_events` - 客服事件主表
- `support_event_logs` - 客服事件日誌表

### 關聯資料表
- `support_chat_rooms` - 客服聊天室
- `support_chat_messages` - 客服聊天訊息
- `support_chat_reads` - 客服聊天已讀狀態
- `users` - 使用者表
- `admins` - 管理員表

## Admin Web 功能

### 1. 客服案件列表
**功能**:
- 顯示所有客服案件 (`support_events`)
- 表格欄位包含案件基本資訊
- Action 欄位: `[detail, 經手(英文)]`

### 2. 案件詳情 Dialog
**觸發點**: 點擊 `detail` 按鈕

**內容**:
- 案件 ID
- 使用者資訊
- 客服項目描述

### 3. 案件接手流程
**觸發點**: 點擊 `經手` 按鈕

**流程**:
1. 二次確認: "是否成為此案件的處理人員？"
2. Loading 等待執行完成
3. 執行以下步驟:
   - `support_events.admin_id` 寫入管理員 ID
   - `support_events.status` 更新為 `'in_progress'`
   - `support_chat_rooms.participant_id` 設為管理員 ID
   - `support_event_logs` 寫入狀態變更記錄

### 4. 客服聊天室
**介面架構**:
- 與任務聊天室基本一致
- 包含 AppBar、聊天氣泡訊息區塊
- 左側: 他方訊息（頭像 + 氣泡）
- 右側: 我方訊息（僅氣泡）

**功能限制**:
- 當 `support_events.status = 'solved'` 時，UI 功能 disable
- 無法傳送圖片和訊息

**Action Bar**:
- 只有 `issue status` 按鈕
- 點擊顯示進度條 Dialog

### 5. 進度條 Dialog
**內容**:
- 三個階段: `submitted` → `in_progress` → `solved`
- 進度條 UI 配色對應當前階段
- 顯示各階段時間戳記 (`support_event_logs.created_at`)

## Flutter App 功能

### 1. 客服需求申請
**頁面**: `/contact-us`

**功能**:
- 顯示當前執行中的客服案件
- 如果沒有案件，顯示"沒有執行中的項目"
- 提供建立客服事件的按鈕

**限制**:
- 最多同時 3 則 `support_events.status in ('submitted', 'in_progress')`
- 達到上限時無法新增

### 2. 客服事件建立
**流程**:
1. 點擊建立按鈕
2. 顯示問題表單
3. 填寫必要欄位
4. 提交後建立 `support_events`
5. 在 `support_event_logs` 寫入記錄

### 3. 客服案件管理
**頁面**: `/issue-status` (使用 tabs 呈現)

**功能**:
- 顯示 `support_events` 列表
- 只顯示 `status in ('submitted', 'in_progress')`
- 不顯示 `solved` 狀態案件
- 每個案件顯示案件編號和時間線

### 4. 客服聊天室
**功能**:
- 與管理員後台聊天室介面一致
- Action Bar 有 `solved` 按鈕
- 可將案件狀態轉為 `solved`

**等待機制**:
- `submitted` 狀態時檢查 `support_chat_rooms.participant_id`
- 如果為空，顯示等待管理員接手的訊息

## 資料表對應關係

### 聊天室相關
| 任務聊天室 | 客服聊天室 |
|-----------|-----------|
| `chat_rooms` | `support_chat_rooms` |
| `chat_reads` | `support_chat_reads` |
| `chat_messages` | `support_chat_messages` |

### 事件及紀錄相關
| 任務爭議事件及紀錄 | 客服事件及紀錄 |
|------------------|---------------|
| `task_dispute_events` | `support_events` |
| `task_dispute_event_logs` | `support_event_logs` |

## 狀態流程

### 客服事件狀態
- `submitted` - 已提交
- `in_progress` - 處理中
- `solved` - 已解決

## 技術實現要點

### 1. 聊天室類型區分
- `chat_rooms.type = 'support'` - 客服聊天室
- `chat_rooms.type = 'application'` - 任務聊天室

### 2. 權限控制
- 管理員需要適當權限才能接手案件
- 使用者只能查看自己的客服案件

### 3. 即時通知
- 案件建立後通知管理員
- 管理員接手後通知使用者

### 4. 資料一致性
- 確保聊天室與事件狀態同步
- 防止重複接手案件

## 相關檔案
- 資料結構定義: `docs/優先執行/客服聊天模組及任務爭議(Dispute)模組需求說明.sql`
- 任務爭議模組: `docs/優先執行/任務爭議(Dispute)模組需求說明.md`
