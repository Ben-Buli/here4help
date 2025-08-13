# 任務/應徵/聊天 - 數據流與路由對照

本文檔梳理 Flutter App 與資料庫之間的對應關係，作為除錯與擴充的快速對照表。

## 一、路由與資料流

### 1) /task/create → /task/create/preview
- 建立任務草稿於前端（使用 SharedPreferences 暫存）
- 欄位：title, description, reward_point, location, task_date, language_requirement, application_questions(0-3)
- 導航：`context.go('/task/create/preview')`

### 2) /task/create/preview → 後端 API 建立任務
- API：`backend/api/tasks/create.php`
- 資料表：
  - `tasks` 新增 1 筆（UUID `id`）
  - `application_questions` 逐題新增（`task_id` 指向新任務）
- 注意：`creator_id` 以登入用戶 `users.id` 寫入；`application_questions` 存問題原文

### 3) /task/apply（任務應徵）
- 畫面：依 `tasks` + `application_questions` 產生應徵表單
- 送出 API：`backend/api/tasks/applications/apply.php`
- 資料表：
  - `task_applications` UPSERT（唯一鍵 `task_id,user_id`）
    - `cover_letter`：自我推薦（唯一來源）
    - `answers_json`：`{"<問題原文>": "<回答>", ...}`
- 聊天室：成功應徵後呼叫 `ensure_room` 建立 `chat_rooms`，並跳轉 `/chat/detail`

### 4) /chat/detail（聊天室詳情）
- 上方標題：`ChatTitleWidget` 動態顯示任務標題與對象名稱（依角色 creator/participant）
- 訊息：
  - 初始載入：`chat_messages`（`room_id` = `chat_rooms.id`）
  - 發送：`send_message.php` 寫入 `chat_messages` 並透過 Socket 推播
- View Resume：
  - 來源：`task_applications` 以 `task_id + participant_id` 擷取
  - 顯示：`cover_letter` + `answers_json`（鍵為問題原文）

## 二、資料表對照

### tasks
- `id` (UUID), `creator_id`, `acceptor_id`, `title`, `description`, `reward_point`, `location`, `task_date`, `status_id`, ...

### application_questions
- `id` (UUID), `task_id` (UUID), `application_question` (TEXT)
- 用途：任務發布者自訂問題（0-3）

### task_applications
- `id` (BIGINT AI), `task_id` (UUID), `user_id` (BIGINT), `cover_letter` (TEXT), `answers_json` (JSON)
- `answers_json` 鍵 = 問題原文，值 = 應徵者回答

### chat_rooms
- `id` (BIGINT AI), `task_id` (UUID), `creator_id` (BIGINT), `participant_id` (BIGINT), `type` ('application'|'task')
- 建立：`ensure_room.php` 以 (task_id, creator_id, participant_id, type) 確保唯一

### chat_messages
- `id` (BIGINT AI), `room_id` (BIGINT), `from_user_id` (BIGINT), `message` (TEXT), `created_at`
- 來源：`send_message.php`；即時：Socket `send_message`

## 三、重要一致性規則

1. `chat_rooms.participant_id` 必須對齊 `task_applications.user_id`（否則 View Resume 會找不到資料）
2. `answers_json` 一律採用「問題原文」作鍵；不再使用 `q1/q2/q3/introduction`
3. 自我推薦只用 `task_applications.cover_letter`
4. Web 刷新：`ChatDetailWrapper` 優先從 Session → LocalStorage → URL 恢復資料

## 四、常見除錯查詢

查任務的應徵紀錄：
```sql
SELECT user_id, cover_letter, JSON_PRETTY(answers_json)
FROM task_applications
WHERE task_id = '<task_id>'
ORDER BY updated_at DESC;
```

查聊天室與參與者：
```sql
SELECT id, task_id, creator_id, participant_id
FROM chat_rooms
WHERE id = <room_id>;
```

## 五、假資料與補齊腳本（摘要）
- 自動補三題：依任務標題/日期/語言產生通用題
- 以問題原文鍵產生 answers_json 假資料
- 對齊聊天室 participant_id 到最新應徵者

詳見：
- `docs/development-logs/DATABASE_SYNC_ANALYSIS_2025_01_11.md`
- `docs/development-logs/CHAT_PERSISTENCE_IMPLEMENTATION.md`
