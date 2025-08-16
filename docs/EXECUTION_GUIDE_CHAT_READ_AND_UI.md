## 即時聊天室・未讀數與列表 UI 執行指南（臨時開發文件）

來源與範圍：本指南由對話任務（request id: a3fc2a7f-cd33-41b9-a1ea-786e761a1363）萃取，僅作為臨時開發與驗收依據。待你最終同意全數完成後，將要點整合回 `docs/TODO_INTEGRATED.md`、`docs/TODO_DASHBOARD.md`、`docs/CURSOR_TODO.md` 並在本檔案備註來源與收束狀態。

重要流程與驗收原則：每一階段務必先完成「自動檢查（後端 API / 端到端腳本）」+「手動操作驗收（App 實際操作）」兩者，雙方整合成簡報告後，經你確認同意，方可進入下一階段。

---

### 新增需求（2025-08-16）
- Tab 小紅點：當各分頁（Posted / My Works）存在任一未讀時，在分頁文字右上角顯示 6px 警示色圓點。
- 未讀圓點/數字樣式：移除所有陰影，僅保留純色圓點與純色圓角數字徽章。
- 已讀寫回規則：列表未讀狀態僅以 `unread_snapshot.by_room` 合併，不在 UI 事件直接清除；必須在聊天室內完成 `read_room` 寫入後，快照更新才扣除。
- 聊天室滾動定位：支援「保留使用者最後一次讀取位置」。後端在 `get_messages.php` 回傳 `my_last_read_message_id`，前端載入後定位至該訊息鄰近位置；並在到達底部/離開頁面時上報 `markRoomRead()`。

### 修正項目（2025-08-16）
- **Reset 無限刷新修正**：解決點擊 reset icon 造成無限 API 調用的問題
  - 根本原因：`_updateTabUnreadFlag()` 觸發 Provider 通知 → 引發 `_handleProviderChanges()` → 再次刷新 → 形成無限循環
  - 解決方案：在未讀標記更新前檢查狀態是否真正改變，避免不必要的 Provider 通知
  - 影響組件：`PostedTasksWidget`、`MyWorksWidget`

- **頭像重複錯誤修正**：解決展開任務卡片時重複顯示相同 404 錯誤的問題
  - 根本原因：Widget 重建時 `_AvatarWithFallback` 重新創建，每次都重置錯誤狀態並重新嘗試載入已知失敗的圖片
  - 解決方案：創建全域 `AvatarErrorCache` 靜態快取，記錄已知失敗的 URL，避免重複載入
  - 實作：
    - 新建 `lib/chat/utils/avatar_error_cache.dart` 工具類別
    - 快取管理：最多 100 個失敗 URL，自動清理舊條目防止記憶體洩漏
    - 頭像 Widget 檢查快取，已知失敗的 URL 立即顯示首字母頭像
  - 影響組件：`PostedTasksWidget._AvatarWithFallback`、`MyWorksWidget._MyWorksAvatarWithFallback`
  - 用戶體驗：避免重複的 404 錯誤訊息，提升載入效能和 UI 響應性

- **未讀標記顯示問題分析**（待修正）：
  - **根本問題**：資料庫架構不一致
    - 原始 `chat_rooms` 表：只有 `id`, `task_id` 欄位（MVP 結構）
    - 遷移腳本：定義了包含 `creator_id`, `participant_id` 的新結構
    - 現有 API：`get_rooms.php`, `ensure_room.php` 假設表有 `creator_id`, `participant_id`
    - **`unread_snapshot.php`**：使用 `(cr.creator_id = ? OR cr.participant_id = ?)` 條件，但欄位可能不存在
  - **解決方案**：創建新的未讀 API，從任務申請關係反推聊天室與未讀狀態
    - 不依賴 `chat_rooms.creator_id/participant_id`
    - 從 `task_applications` + `tasks` 推導聊天關係
    - 基於 `chat_messages.from_user_id` 和 `chat_reads` 計算未讀數

### Phase 1（進行中）- 全域未讀初始化與底部導覽圓點（改用警示色）
- 目標：
  - App 啟動或登入成功後，初始化未讀中心（Socket + 快照），能即時接收 `unread_total`/`unread_by_room`。
  - Bottom Navbar 的 Chat 圖示：改為「純圓點」指示（無數字），當總未讀 > 0 時顯示，否則不顯示。全域即時。圓點採用主題的 warning/alert 色（若無專屬 warning，則以主題 `colorScheme.error` 或替代 alert 色近似呈現）。
- 後端自動檢查：
  - `backend/api/chat/unread_snapshot.php` 可用；`backend/api/chat/read_room.php` 可用；若缺 `chat_reads` 則建表。
  - cURL（以 users.id=2）：生成 base64 token 後呼叫 snapshot/mark read，確認數值變化。
- 前端自動檢查：
  - 登入成功後於 Console 觀察 Socket 連線、`refreshSnapshot()` 成功回傳、`totalUnreadStream` 有輸出。
- 手動操作驗收：
  1) 登入帳號 `Luisa@test.com / 1234`。
  2) 進入 Home → 切換至 Chat，觀察底部導覽是否顯示圓點（若有未讀）。
  3) 進入任一聊天室 → 返回列表，圓點是否即時更新（若該房已讀導致 total=0，圓點應消失）。
- 完成條件：
  - 自動 + 手動驗收皆通過，並在本檔「進度追蹤」打勾，附上你與我整合的簡報告摘要。

---

### Phase 2 - 兩分頁排序聚攏與 Emoji 規則
- 目標：
  - Posted / My Works 以 `status.sort_order` → `updated_at DESC` 統一排序（同狀態聚攏）。
  - Emoji 狀態列：`popular > new`，若 popular=true 則只顯示 🔥，否則在 new=true 才顯示 🌱。
- 自動檢查：
  - 任務列表 API 回傳含 `sort_order`。
  - 單元或簡測：排序結果符合期望鍵順序。
- 手動操作驗收：
  - 切換 /chat 兩分頁，觀察任務排列是否聚攏；Emoji 顯示符合優先規則。

---

### Phase 3 - 應徵者卡片頭像與未讀徽章樣式（Posted + My Works）
- 目標：
  - Posted 分頁應徵者卡片顯示 `applier_avatar`（無則首字母）。
  - 任務卡片右側：移除應徵人數數字（如截圖中的「2」）。改為與底部 navbar 一致的「純圓點」（無數字），只要該任務下任一應徵者聊天室存在未讀就顯示。圓點採用主題 warning/alert 色。
  - 應徵者卡片右側：保留「未讀數字徽章」，為主題 warning/alert 色圓形，中間白色數字，表示該聊天室未讀訊息數。
  - My Works 分頁依同等狀態邏輯呈現未讀（任務卡片顯示圓點；聊天室/對象卡片顯示未讀數字）。
- 自動檢查：
  - 後端 `posted_tasks_aggregated.php` applicants 欄位含 `applier_avatar`。
- 手動操作驗收：
  - 展開 Posted 應徵者清單核對頭像/佔位邏輯；未讀徽章樣式符合設計。

---

### 未讀統一對接策略（方案 A，採用）
- 原則：不在聚合 API 計算未讀；統一使用 `chat/unread_snapshot.php`（回傳 `by_room`）做合併，以保效能與一致性。
- 後端改動：
  - `backend/api/tasks/applications/list_by_user.php` 增加 `chat_room_id` 欄位：
    ```sql
    LEFT JOIN chat_rooms cr ON cr.task_id = t.id
      AND cr.participant_id = ta.user_id
      AND cr.creator_id = t.creator_id
    -- SELECT 欄位：cr.id AS chat_room_id
    ```
  - `posted_tasks_aggregated.php` 既有 `applicants[].chat_room_id` 可直用。
- 前端對接：
  - 兩分頁皆透過 `NotificationCenter.byRoomStream` 取得 `room_id → 未讀數`：
    - Posted：
      - 任務卡：聚合其 applicants 的 `chat_room_id` 是否任一未讀 > 0 → 顯示警示色圓點
      - 應徵者卡：使用 `by_room[chat_room_id]` 顯示未讀數字徽章
    - My Works：
      - 每個卡片含 `chat_room_id`；卡片顯示圓點與/或未讀數字徽章（與 Posted 同規）
  - 分頁小紅點：各分頁於合併 `by_room` 後彙總是否存在未讀，更新 Provider `setTabHasUnread(tabIndex, bool)`，tab 標籤右上顯示 6px 警示色圓點。
- 驗證：
  - 後端：
    ```bash
    curl -sS "$BASE/backend/api/tasks/applications/list_by_user.php?user_id=2&limit=5" | jq '.data.applications[] | {task_id: .id, chat_room_id}'
    curl -sS -H "Authorization: Bearer $TOKEN" "$BASE/backend/api/chat/unread_snapshot.php" | jq '.data.by_room'
    ```
  - 前端：`byRoomStream` 的未讀與卡片圓點/數字對應一致。

---

### 未讀數計算定義（資料處理準則）
- 定義：對「當前用戶」而言，某房間的未讀數 = 該房間中「他人發送」且 `id > my.last_read_message_id` 的訊息數。
- 等價 SQL（以 `users.id = :uid`）：
  ```sql
  SELECT m.room_id,
         SUM(CASE WHEN m.from_user_id <> :uid AND m.id > COALESCE(r.last_read_message_id, 0)
                  THEN 1 ELSE 0 END) AS unread_cnt
  FROM chat_messages m
  JOIN chat_rooms cr ON cr.id = m.room_id
  LEFT JOIN chat_reads r ON r.room_id = m.room_id AND r.user_id = :uid
  WHERE (cr.creator_id = :uid OR cr.participant_id = :uid)
  GROUP BY m.room_id;
  ```
- 說明：不使用「對方已讀你訊息」來計算你的未讀；那是已讀回執顯示（`opponent_last_read_message_id`）用，與你的未讀數無關。

---

### Phase 4 - 最新訊息預覽（Posted 應徵者卡片）
- 目標：
  - 每位應徵者的卡片顯示該應徵者對應聊天室最新訊息（若無則回退 cover letter 片段）。
- 後端改動：
  - `posted_tasks_aggregated.php` 每個 applicant 帶 `chat_room_id`、`latest_message_snippet`（查 `chat_messages` 最新 message）。
- 手動操作驗收：
  - 開啟 Posted 應徵者卡片，確認顯示的確為最新訊息片段。

---

### Phase 5 - My Works 卡片顯示聊天對象 + 最新訊息
- 目標：
  - My Works 每個任務項目顯示「聊天對象（任務建立者）」與「最新一則訊息預覽」。
- 後端改動：
  - `applications/list_by_user.php` 增補 `chat_room_id`、`chat_partner_name/avatar_url`、`latest_message_snippet`。
- 手動操作驗收：
  - 進入 My Works，核對聊天對象頭像/名稱與最新訊息片段。

---

### Phase 6 - /chat/detail 返回列表刷新（僅當前分頁）
- 目標：
  - 從聊天室返回 /chat 時，只刷新當前分頁資料，不整頁重載，不會出現空白。
- 手動操作驗收：
  - 進入/返回多次，確認穩定性。

---

### Phase 7 - Task Edit 預填 start/end
- 目標：
  - Posted → Edit 表單預填 `start_datetime`/`end_datetime`。
- 自動檢查：
  - `task_edit_data.php` 回傳含 start/end。
- 手動操作驗收：
  - 進入 Edit 頁，確認 Posting Period 控件內有正確起訖時間。

---

### Phase 8 - 聊天室滾動定位與已讀機制（新增）
- 目標：
  - 後端：`backend/api/chat/get_messages.php` 回傳 `my_last_read_message_id`。
  - 前端：
    - `ChatDetailPage` 載入訊息後定位至 `my_last_read_message_id` 鄰近位置，顯示「新訊息」提示。
    - 進房載入完成、到達底部、離開頁面時，上報 `markRoomRead(roomId, upToMessageId)`，以列表最後一則訊息 ID 為準。
  - 列表端：未讀僅依快照變化；不因返回列表而自行清除。
- 自動檢查：
  - `get_messages.php` JSON 中出現 `my_last_read_message_id`。
  - 進房後再呼叫快照，該房 by_room 應遞減或為 0。
- 手動操作驗收：
  - 打開聊天室 → 返回 → 該房未讀消失或遞減；分頁 Tab 與任務卡/應徵者卡一致更新。

## 終端機測試指令（以 users.id=2）
```bash
# 產生 token（macOS zsh）
TOKEN=$(python3 - <<'PY'
import base64, json
print(base64.b64encode(json.dumps({"user_id":2,"exp":4102444800}).encode()).decode())
PY
)
BASE="<YOUR_BASE_URL>"  # 例: http://localhost:8888/here4help

# 未讀快照
curl -sS -H "Authorization: Bearer $TOKEN" "$BASE/backend/api/chat/unread_snapshot.php" | jq

# 標記聊天室已讀 → 再快照
curl -sS -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"room_id":"<ROOM_ID>"}' "$BASE/backend/api/chat/read_room.php" | jq
curl -sS -H "Authorization: Bearer $TOKEN" "$BASE/backend/api/chat/unread_snapshot.php" | jq

# 編輯資料檢查（確認 start/end）
curl -sS "$BASE/backend/api/tasks/task_edit_data.php?id=<TASK_ID>" | jq

# Posted 聚合（待補 latest_message_snippet 後再重跑）
curl -sS "$BASE/backend/api/tasks/posted_tasks_aggregated.php?creator_id=2&limit=5" | jq '.data.tasks[0].applicants[0]'
```

### SQL 驗證（在資料庫中）
```sql
-- 使用你的 DB 客戶端連線後執行（以 :uid = 2）
-- 1) 查每房未讀數
SELECT m.room_id,
       SUM(CASE WHEN m.from_user_id <> 2 AND m.id > COALESCE(r.last_read_message_id, 0)
                THEN 1 ELSE 0 END) AS unread_cnt
FROM chat_messages m
JOIN chat_rooms cr ON cr.id = m.room_id
LEFT JOIN chat_reads r ON r.room_id = m.room_id AND r.user_id = 2
WHERE (cr.creator_id = 2 OR cr.participant_id = 2)
GROUP BY m.room_id
ORDER BY m.room_id;

-- 2) 檢查雙方最後已讀（讀回執顯示用途）
SELECT user_id, room_id, last_read_message_id FROM chat_reads WHERE room_id IN (
  SELECT id FROM chat_rooms WHERE creator_id = 2 OR participant_id = 2
);
```

---

## 手動驗收清單（逐階段）
- Phase 1：
  - 登入 `Luisa@test.com / 1234` → 底部 Chat 圖示顯示圓點（若有未讀）。
  - 進入任一聊天室後返回 → 圓點狀態即時變更（total=0 時隱藏）。
- Phase 2：
  - 兩分頁排序聚攏；Emoji 規則 popular>new 生效。
- Phase 3：
  - 應徵者頭像顯示正確；卡片未讀徽章主題色、圓形、中心數字。
- Phase 4：
  - Posted 應徵者卡片顯示最新訊息預覽。
- Phase 5：
  - My Works 卡片顯示聊天對象與最新訊息預覽。
- Phase 6：
  - 從 /chat/detail 返回 /chat 僅刷新當前分頁，穩定無空白。
- Phase 7：
  - Edit 表單預填 start/end。

---

## 進度追蹤
- [✅] Phase 1：全域未讀初始化與底部導覽圓點（已完成）
  - `NotificationCenter` 初始化與 Socket 連接正常
  - `unread_snapshot.php` SQL 群組問題已修正（避免笛卡爾積重複計算）
  - 底部 Chat 圖示純圓點顯示邏輯正常，警示色已套用
  - `PostedTasksWidget` 與 `MyWorksWidget` 透過 `byRoomStream` 正確對接
- ✅ Phase 2：排序聚攏 + Emoji 規則（status.sort_order → updated_at DESC，popular > new emoji 優先級）
- ✅ Phase 3：應徵者頭像 + 未讀徽章樣式（實際頭像顯示、評分與名稱同一行、移除舊評分）
- ✅ Phase 4：Posted 最新訊息預覽（後端查詢最新聊天訊息、前端顯示 latest_message_snippet）
- ✅ Phase 5：My Works 聊天對象 + 最新訊息（後端增加片段、前端顯示創建者頭像名稱與訊息）
- ✅ Phase 6：返回分頁刷新（已通過 reset 無限刷新修正解決）
- ✅ Phase 7：Edit 預填 start/end（修正編輯模式的 start_datetime/end_datetime 預填邏輯）

**⚠️ 未讀標記問題**：資料庫架構不一致導致 `unread_snapshot.php` 無法正常工作，已創建 `unread_by_tasks.php` 作為替代方案。

備註：本檔為臨時開發指南；所有階段完成並經你最終同意後，會整合回各 TODO 文檔並在此檔標記來源與歸檔。


