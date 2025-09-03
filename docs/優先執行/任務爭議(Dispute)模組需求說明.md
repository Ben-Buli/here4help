# 任務爭議(Dispute)模組需求說明

## 概述
任務爭議模組允許使用者在任務執行過程中提出爭議，管理員可以介入處理並做出決策。該模組與客服聊天模組結構類似但用途不同。

## 資料表結構

### 核心資料表
- `task_dispute_events` - 任務爭議事件主表
  - `task_id` - 關聯的任務ID
  - `task_dispute_chat_room_id` - 爭議聊天室ID
  - `user_id` - 填表人ID
  - `title` - 爭議標題 (varchar255)
  - `description` - 爭議描述
  - `status` - 狀態 (submitted, in_progress, solved)
- `task_dispute_event_logs` - 任務爭議事件日誌表
  - 適用於紀錄管理員對於 'submitted' 狀態的dispute event操作的紀錄

### 關聯資料表
- `chat_rooms` - 任務聊天室 (type = 'application')
- `chat_messages` - 聊天訊息
- `chat_reads` - 聊天已讀狀態
- `tasks` - 任務主表
- `task_applications` - 任務申請表
- `users` - 使用者表

### 停用的資料表
以下資料表已停用，不應再使用：
- `dispute_chats`
- `task_disputes`
- `task_dispute_chat_messages`
- `task_dispute_chat_rooms`

## Flutter App 功能

### 1. 任務爭議申請
**觸發點**: `/chat/detail` 頁面的 Action Bar 中的 'dispute' 按鈕

**驗證流程**:
1. 點擊 'dispute' 按鈕時，預先檢測該聊天室ID是否已存在於 `task_dispute_events` 表中
2. 如果已存在，顯示英文說明："已送出此爭議(dispute)申請請等待審核"
3. 如果不存在，顯示 Dispute Dialog

**Dispute Dialog 表單**:
- **欄位**: 只顯示 `title` 和 `description` 兩個欄位
- **驗證要求**:
  - 必填檢驗
  - 標題和描述都有字數統計 (0/0)
  - 錯誤處理: error labelText 紅字顯示
  - 處理後端送來的資料錯誤問題（送出失敗、該任務聊天室已存在等）

**提交流程**:
1. 表單驗證無錯誤
2. 寫入 `task_dispute_events` 表
3. 使用 `userActiveLogger()` 記錄使用者將 `tasks.id` 和 `tasks.status_id` 的資料送出dispute爭議申請
4. 成功寫入後，修改 `tasks.status_id => 4` (= `task_statuses.code='dispute'`)
5. 顯示成功訊息，包含案件編號和進度時間線

**重要注意事項**:
- 需要確認 `tasks.status_id = 3` (pending confirmation) 的7*24小時倒數計時功能
- 確認倒數計時的基準時間戳點
- 確認轉為dispute狀態時是否會自動取消倒數（例如panel cron），還是需要手動取消或處理

### 2. 爭議案件查看
**頁面**: `/issue-status` 分頁中的「任務爭議進度列表」

**功能**:
- 顯示 `task_dispute_events` 和 `task_dispute_event_logs` 資料
- 只顯示 `status in ('submitted', 'in_progress')` 的案件
- 不顯示 `solved` 狀態的案件
- 每個案件項目顯示：
  - 案件編號
  - 時間線進度
  - 當前狀態

### 3. 爭議案件詳情
**觸發點**: 在 `/chat/detail` 中點擊 'dispute' 按鈕（已建立案件後）

**功能**:
- 顯示已建立案件的進度時間線
- 顯示案件編號
- 提示使用者可前往 `/issue-status` 頁面查看詳細進度

## Admin Web 功能

### 1. 爭議任務列表頁面
**功能**:
- 依照 `task_dispute_events` 的資料設計一個table「任務爭議列表」
- 顯示所有任務爭議案件
- 表格欄位包含：
  - 提案人 (`users.id`)
  - 爭議事件編號 (`task_dispute_events.id`)
  - 任務相關資訊
  - Action 欄位

**互動功能**:
- Table > tr (row) 點擊進去可查看詳細資訊

### 2. Action 功能
**按鈕**:
- `room` - 進入該爭議案件的聊天室
- `operation` - 管理員決策操作

### 3. 管理員決策 Dialog
**觸發點**: 點擊 `operation` 按鈕

**內容**:
- 決策結果 (status)
- 決策說明 (description)

**決策選項**:
1. **任務完成** (`tasks.status_id = 5`)
   - 直接結案
   - 轉移點數
   - 扣除額外手續費
   - 執行對應 API

2. **任務未完成** (`tasks.status_id = 2`)
   - 回到進行中狀態 (in progress)

3. **任務重置** (`tasks.status_id = 1`)
   - 移除現有任務執行者 (`tasks.participant_id = null`)
   - 原本執行者的申請狀態改為 `task_applications.status = 'cancelled'`

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

### 任務狀態變更
1. **正常任務** → **爭議狀態**
   - 觸發: 使用者提交爭議
   - 變更: `tasks.status_id = 4` (dispute)

2. **爭議狀態** → **決策後狀態**
   - 完成: `tasks.status_id = 5`
   - 進行中: `tasks.status_id = 2`
   - 重置: `tasks.status_id = 1`

### 爭議事件狀態
- `submitted` - 已提交
- `in_progress` - 處理中
- `solved` - 已解決

## 技術實現要點

### 1. 表單驗證
- 爭議原因必填
- 描述內容長度限制
- 防止重複提交
- 字數統計顯示
- 錯誤訊息紅字顯示

### 2. 權限控制
- 只有任務相關人員可以提交爭議
- 管理員需要適當權限才能處理爭議

### 3. 即時通知
- 爭議提交後通知相關人員
- 管理員決策後通知申請人

### 4. 資料一致性
- 確保任務狀態與爭議狀態同步
- 防止資料不一致的情況
- 防止重複建立爭議案件

### 5. 倒數計時處理
- 確認 `tasks.status_id = 3` (pending confirmation) 的7*24小時倒數計時機制
- 確認轉為dispute狀態時的倒數計時處理方式
- 可能需要手動取消或自動處理

### 6. 日誌記錄
- 使用 `userActiveLogger()` 記錄爭議申請
- 在 `task_dispute_event_logs` 記錄管理員操作
- 確保所有重要操作都有日誌記錄

## 相關檔案
- 資料結構定義: `docs/優先執行/0903＿任務爭議dispute資料結構.sql`
- 客服模組對比: `docs/優先執行/客服聊天模組及任務爭議(Dispute)模組需求說明.md`