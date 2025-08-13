## Here4Help - 快速索引與路由對照（簡版）

此文件彙整「主要路由 ↔ 對應程式 ↔ 後端 API ↔ 資料表」的快速索引，便於開發與除錯。

### 路由對照與資料流

- /task/create
  - 前端：`lib/task/pages/task_create_page.dart`
  - 說明：建立任務（表單 → SharedPreferences 暫存）
  - 後續：→ `/task/create/preview`

- /task/create/preview
  - 前端：`lib/task/pages/task_preview_page.dart`
  - API：`backend/api/tasks/create.php`
  - 資料表：`tasks`（UUID 主鍵）、`application_questions`
  - 重點：送出建立任務與自訂問題（問題原文為 keys）

- /task
  - 前端：`lib/task/pages/task_list_page.dart`
  - API：`backend/api/tasks/list.php`
  - 說明：任務大廳（英文化篩選、排序含 reward_point）

- /task/apply
  - 前端：`lib/task/pages/task_apply_page.dart`
  - API：`backend/api/tasks/applications/apply.php`
  - 資料表：`task_applications`（`cover_letter`、`answers_json`）
  - 重點：
    - 送出後呼叫 `ensure_room` 建立/取得聊天室（BIGINT `room_id`）
    - 已實作「自動首則訊息」：應徵成功後，前端會以 `cover_letter`（加上回答摘要）呼叫 `chat/send_message.php` 寫入 `chat_messages`，並嘗試透過 Socket 推播

- /chat（列表）
  - 前端：`lib/chat/pages/chat_list_page.dart`
  - 說明：分頁 `Posted Tasks` / `My Works`
    - Posted Tasks：點擊一律先 `ensure_room` 取得 BIGINT `room_id`
    - My Works：若該任務下沒有現成房間，會回退呼叫 `ensure_room` 以目前使用者為 participant 建立/取得房間後導頁

- /chat/posted-tasks（直達分頁）
  - 前端：`lib/chat/pages/chat_list_page.dart`

- /chat/my-works（直達分頁）
  - 前端：`lib/chat/pages/chat_list_page.dart`

- /chat/detail（聊天室）
  - 容器：`lib/chat/widgets/chat_detail_wrapper.dart`（刷新/回退安全，含舊 `app_*` roomId 回退）
  - 頁面：`lib/chat/pages/chat_detail_page.dart`
  - 標題：`lib/chat/widgets/chat_title_widget.dart`（顯示任務標題/對手名稱與角色）
  - API：`backend/api/chat/ensure_room.php`、`backend/api/chat/get_messages.php`、`backend/api/chat/send_message.php`、`backend/api/chat/get_rooms.php`
  - Socket：`backend/socket/server.js`、`lib/chat/services/socket_service.dart`
  - 資料表：`chat_rooms`、`chat_messages`、`chat_reads`

### 前端關鍵模組

- 路由組態：`lib/router/app_router.dart`、`lib/constants/shell_pages.dart`
- 聊天服務：
  - HTTP：`lib/chat/services/chat_service.dart`
  - Socket：`lib/chat/services/socket_service.dart`
  - 本地持久化：`lib/chat/services/chat_storage_service.dart`
  - 會話：`lib/chat/services/chat_session_manager.dart`
- 任務服務：`lib/task/services/task_service.dart`
- 主題：`lib/services/theme_config_manager.dart`

### 後端 API（PHP）

- 任務：`backend/api/tasks/create.php`、`backend/api/tasks/list.php`
- 應徵：`backend/api/tasks/applications/apply.php`、`backend/api/tasks/applications/list_by_task.php`
- 聊天：`backend/api/chat/ensure_room.php`、`backend/api/chat/get_messages.php`、`backend/api/chat/send_message.php`、`backend/api/chat/get_rooms.php`

### 主要資料表

- `tasks`：任務主檔（UUID）
- `application_questions`：任務自訂問題（以問題原文儲存）
- `task_applications`：應徵紀錄（`cover_letter` + `answers_json`，keys=問題原文）
- `chat_rooms`：聊天室（BIGINT 主鍵；(task_id, creator_id, participant_id, type) 唯一）
- `chat_messages`：聊天訊息（`room_id` 對應 `chat_rooms.id`）
- `chat_reads`：已讀狀態
- `users`：用戶

注意與一致性：
- `chat_rooms.participant_id` 應與該任務的應徵者 `task_applications.user_id` 對齊
- 僅保留 `cover_letter` 作為自我推薦；`answers_json` 使用問題原文為 keys
- 發訊息 API `room_id` 必須為 BIGINT（或數字字串）

### 常用除錯 SQL（節錄）

- 查任務的應徵：
```sql
SELECT user_id, cover_letter, JSON_PRETTY(answers_json)
FROM task_applications
WHERE task_id = '<task_id>'
ORDER BY updated_at DESC;
```

- 查聊天室與參與者：
```sql
SELECT id, task_id, creator_id, participant_id
FROM chat_rooms
WHERE id = <room_id>;
```

- 查最新訊息：
```sql
SELECT *
FROM chat_messages
WHERE room_id = <room_id>
ORDER BY created_at DESC
LIMIT 20;
```

### 閱讀建議

- 先讀 `docs/PROJECT_STRUCTURE.md`（專案結構總覽）
- 參考 `docs/TODO_INDEX.md`（進度與任務一覽）
- 配合同頁索引快速定位對應檔案與 API