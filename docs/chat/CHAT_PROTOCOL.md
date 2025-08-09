# Here4Help 聊天協議與未讀聚合規範（CHAT_PROTOCOL）

版本：1.0.0  
範圍：未讀聚合、WebSocket/HTTP 協議、任務狀態機（含 7 日自動完成）、資料模型、通知、安全與相容性

> 關聯文件：任務狀態視覺/行為規範見 `docs/TASK_STATUS_DESIGN.md`。

---

## 1. 任務狀態機與時序

- 主流程：Open → In Progress → Pending Confirmation → Completed（或 Cancelled/Rejected/Dispute）
- 事件定義：
  - tasker 在聊天室點「完成請求」：狀態改為 Pending Confirmation，記錄 `pendingSince` 與 `autoCompleteAt = pendingSince + 7 days`
  - poster 在聊天室點「確認完成」：狀態改為 Completed，觸發點數轉移
  - 自動完成（逾時）：`now >= autoCompleteAt` 時，系統轉為 Completed 並觸發點數轉移
- 任務欄位：`assigned_tasker_id`, `pending_since`, `auto_complete_at`, `completed_at`

---

## 2. 未讀聚合規則

- 定義（單房間）：對於使用者 `U` 在房間 `R` 的未讀數 = 計算所有「由對方發送且 `created_at > last_read_at(U,R)`」的訊息數
- 清除：使用 `message:read { roomId, upToMessageId }` 上報，伺服器更新 `last_read_*` 並廣播
- 聚合層級：
  - per-room：`unreadByRoom[roomId]`
  - per-task：`unreadByTask[taskId] = sum(unreadByRoom for rooms in task)`
  - total：`totalUnread = sum(unreadByTask)`
- 狀態過濾（聚合時）：計入 Open / In Progress / Pending Confirmation；不計 Completed / Cancelled / Rejected
- 系統訊息：預設計入未讀；任務變為 Completed/Cancelled 後，聚合層不再計入
- 同步策略：前端可樂觀更新；伺服器以 `unread:update` 快照覆寫為準

---

## 3. WebSocket 協議（namespace: /chat）

- 認證
  - 連線參數 `auth: { token }` 或連線後 `auth:login { token }`
  - 成功：`auth:ok { userId, protocolVersion: 1 }`

- 加入範圍
  - `rooms:join { roomIds: string[] }`（重連後需再次宣告）
  - `tasks:join { taskIds: string[] }`（可選，用於推送 task 聚合）

- 訊息
  - `message:send { clientMessageId, roomId, type, content, attachments?, meta? }`
  - `message:ack { clientMessageId, messageId, roomId, serverTime }`
  - `message:new { message }`（廣播）

- 已讀/未讀
  - `message:read { roomId, upToMessageId, clientTime }`
  - `unread:request { since? }` → `unread:snapshot { total, byTask, byRoom, version }`
  - `unread:update { total, byTask, byRoom, version }`

- 任務狀態
  - `task:status:update { taskId, from, to, initiator, pendingSince?, autoCompleteAt?, completedAt?, serverTime }`
  - 狀態相關系統訊息：
    - `message:system { roomId, taskId, subtype: 'completion_requested'|'completion_confirmed'|'auto_completed', text, createdAt }`

- 輔助
  - `typing:start|stop { roomId }`
  - `presence:update { userId, status }`

- 重連策略
  - 指數退避：1s → 2s → 5s → 10s（上限 30s）
  - 重連後流程：`rooms:join` → `unread:request` → 拉取最近 `task:status:update`

- 去重與冪等
  - 前端每次 `message:send` 必帶 `clientMessageId`（UUID）
  - 伺服器以 `(userId, clientMessageId)` 去重

---

## 4. HTTP API（backend/api/chat/, backend/api/tasks/）

- Chat
  - `GET /chat/rooms` → 可見房列表（含 `taskId`, `roomId`, `lastMessage`, `unreadCount`）
  - `GET /chat/messages?roomId&before=&after=&limit=`
  - `POST /chat/messages` body: `{ roomId, type, content, clientMessageId, attachments? }`
  - `POST /chat/read` body: `{ roomId, upToMessageId }`
  - `GET /chat/unread-counts?scope=room|task|total` → `{ total, byTask, byRoom }`

- Tasks（完成流程）
  - `POST /tasks/request-completion`（tasker）
  - `POST /tasks/confirm-completion`（poster；原子化點數轉移）
  - `GET /tasks/:id/status` → `{ status, pendingSince?, autoCompleteAt?, completedAt?, assignedTaskerId }`
  - 皆支援 `Idempotency-Key`，伺服器去重

---

## 5. 資料模型（伺服器）

- `chat_rooms`：`id`, `task_id`, `created_by`, `participants(json)`, `status`
- `chat_messages`：`id`, `room_id`, `sender_id`, `type(text|image|file)`, `content`, `attachments(json)`, `created_at`, `client_message_id`
- `chat_reads`：（複合鍵 `room_id + user_id`）`last_read_message_id`, `last_read_at`
- `tasks` 增欄：`assigned_tasker_id`, `pending_since`, `auto_complete_at`, `completed_at`
- `point_transactions`：`user_id`, `transaction_type(earn|spend|hold)`, `amount`, `related_task_id`, `status`, `created_at`
- （可選）`task_events`：審計任務狀態變更

聚合查詢（排除 Completed/Cancelled）：
```
WHERE task.status IN ('open','in_progress','pending_confirmation')
  AND messages.sender_id != :me
  AND messages.id > chat_reads.last_read_message_id
```

---

## 6. 離線、快取與啟動流程

- 前端快取結構：`{ version, total, byTask, byRoom, updatedAt }`
- 啟動：先 `loadCache()` 顯示舊值 → 連線後 `unread:request` 覆寫
- 無網路：訊息排隊；上線後按序送出；憑 `clientMessageId` 去重

---

## 7. 通知策略（站內/推播）

- 轉入 Pending：雙方通知（需要動作）
- T-24h：提醒 poster 確認完成
- 自動完成：雙方通知，並投遞 `message:system`

---

## 8. 安全與權限

- JWT 驗證；僅可讀寫自己參與之房與任務
- `request-completion` 僅 tasker；`confirm-completion` 僅 poster
- 與點數相關操作使用資料庫交易；以 `(taskId, idempotencyKey)` 去重避免重複扣轉

---

## 9. 相容性與升版

- `protocolVersion = 1`；伺服器於 `auth:ok` 回傳版本
- 版本不符時：前端可回退至 HTTP 快照或提示升級

---

## 10. 前端接線指引（摘要）

- `app_scaffold.dart`：訂閱 `observeTotalUnread()` 顯示 Navbar 徽章
- `chat_list_page.dart`：訂閱 per-room/per-task 未讀；點進房間底部觸發 `message:read`
- `chat_detail_page.dart`：處理 `message:new/ack/read`、`task:status:update`、倒數顯示
- `global_chat_room.dart`：輸出房間/訊息流；由通知服務聚合未讀

> 建議先以 UI（任務 20）落地並預留 `NotificationService` 介面，再以 GPT‑5 完成任務 26 與 21 的跨模組與通訊協議實作。

