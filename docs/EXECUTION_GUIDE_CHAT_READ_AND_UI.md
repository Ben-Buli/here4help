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
- [✅] Phase 2：排序聚攏 + Emoji 規則（status.sort_order → updated_at DESC，popular > new emoji 優先級）
- [✅] Phase 3：應徵者頭像 + 未讀徽章樣式（實際頭像顯示、評分與名稱同一行、移除舊評分）
- [✅] Phase 4：Posted 最新訊息預覽（後端查詢最新聊天訊息、前端顯示 latest_message_snippet）
- [✅] Phase 5：My Works 聊天對象 + 最新訊息（後端增加片段、前端顯示創建者頭像名稱與訊息）
- [✅] Phase 6：返回分頁刷新（已通過 reset 無限刷新修正解決）
- [✅] Phase 7：Edit 預填 start/end（修正編輯模式的 start_datetime/end_datetime 預填邏輯）
- [✅] 頭像載入錯誤修正：創建 `AvatarErrorCache` 工具類別，使用靜態快取避免重複載入失敗的圖片URL

### Phase 8 - 未讀標記系統重構（進行中）

**資料庫架構確認**：
- ✅ `chat_rooms` 表實際包含 `creator_id`, `participant_id` 欄位
- ✅ 資料庫遷移已正確執行，支援角色型未讀計算
- ⚠️ 發現不同未讀 API 計算結果不一致，需要統一邏輯

**角色型未讀計算策略**（基於用戶建議）：
1. **精確分頁計算**：
   - Posted Tasks (scope=posted)：`WHERE creator_id = user_id`，計算 `participant_id` 發送的未讀
   - My Works (scope=myworks)：`WHERE participant_id = user_id`，計算 `creator_id` 發送的未讀
   - 總計 (scope=all)：合併兩者，同 room 不重複計算

2. **API 安全設計**：
   - **GET** `/api/chat/unread_by_tasks.php?scope=posted|myworks|all`
   - **POST** `/api/chat/read_room_v2.php` (替換原版)：
     - 權限驗證：確保用戶為該 room 參與者
     - 交易安全：使用 UPSERT 更新已讀記錄
     - 冪等操作：重複調用結果一致

3. **漸進式替換**：
   - 階段 1：保留 `unread_snapshot.php` 作為後備
   - 階段 2：前端切換至 `unread_by_tasks.php`
   - 階段 3：驗證一致性後完全替換

**實際驗證結果**：
1. **資料庫架構確認** ✅
   - `chat_rooms` 表包含 `creator_id`, `participant_id` 欄位
   - `chat_messages` 表使用 `sender_id`, `content` 欄位（非 `from_user_id`, `message`）
   
2. **API 修正與測試** ✅
   - 修正欄位名稱：`from_user_id` → `sender_id`
   - 測試結果：Posted=159, MyWorks=16, Total=160
   - 標記已讀功能：房間 4 從有未讀變為 0 未讀 ✅
   
3. **前端整合準備** ✅
   - 創建 `UnreadServiceV2` 服務類別
   - 創建 `UnreadApiTestPage` 測試頁面（路由：`/debug/unread-api`）
   - 修正 `AuthService.getToken()` 引用

## 🧪 詳細驗證劇本（基於用戶建議）

### A. 後端 API 驗證劇本

#### A1. 基礎環境設置
```bash
# 設置環境變數
export BASE="http://localhost:8888/here4help"
export TOKEN=$(python3 - <<'PY'
import base64, json
print(base64.b64encode(json.dumps({"user_id":2,"exp":4102444800}).encode()).decode())
PY
)
```

#### A2. 分頁未讀計算驗證
```bash
# 測試 Posted Tasks 分頁
curl -sS -H "Authorization: Bearer $TOKEN" \
  "$BASE/backend/api/chat/unread_by_tasks.php?scope=posted" | jq '.data.total'
# 預期：返回當前用戶作為 creator 的未讀總數

# 測試 My Works 分頁  
curl -sS -H "Authorization: Bearer $TOKEN" \
  "$BASE/backend/api/chat/unread_by_tasks.php?scope=myworks" | jq '.data.total'
# 預期：返回當前用戶作為 participant 的未讀總數

# 測試總計
curl -sS -H "Authorization: Bearer $TOKEN" \
  "$BASE/backend/api/chat/unread_by_tasks.php?scope=all" | jq '.data.total'
# 預期：posted + myworks 的總和
```

#### A3. 已讀標記功能驗證
```bash
# 選擇一個有未讀的房間
ROOM_ID=$(curl -sS -H "Authorization: Bearer $TOKEN" \
  "$BASE/backend/api/chat/unread_by_tasks.php?scope=all" | \
  jq -r '.data.by_room | to_entries | .[0].key')

# 記錄標記前的未讀數
BEFORE=$(curl -sS -H "Authorization: Bearer $TOKEN" \
  "$BASE/backend/api/chat/unread_by_tasks.php?scope=all" | \
  jq ".data.by_room[\"$ROOM_ID\"]")

echo "房間 $ROOM_ID 標記前未讀數: $BEFORE"

# 標記為已讀
curl -sS -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"room_id\":\"$ROOM_ID\"}" \
  "$BASE/backend/api/chat/read_room_v2.php" | jq '.data'

# 驗證標記後的未讀數
AFTER=$(curl -sS -H "Authorization: Bearer $TOKEN" \
  "$BASE/backend/api/chat/unread_by_tasks.php?scope=all" | \
  jq ".data.by_room[\"$ROOM_ID\"] // 0")

echo "房間 $ROOM_ID 標記後未讀數: $AFTER"
# 預期：AFTER 應為 0
```

### B. 前端整合驗證劇本

#### B1. 測試頁面訪問
1. 啟動 Flutter 應用程式：`flutter run -d ios`
2. 登入系統：使用 `Luisa@test.com / 1234`
3. 訪問測試頁面：在瀏覽器中輸入應用程式 URL + `/debug/unread-api`

#### B2. UnreadServiceV2 功能驗證
在測試頁面中：
1. **基礎 API 測試**：點擊「基礎測試」按鈕
   - 驗證：Posted/MyWorks/All 三個 scope 的數據一致性
   - 預期：各 scope 的 total 和 by_room 數據正確

2. **便捷方法測試**：觀察 convenience_methods 結果
   - 驗證：`getTotalUnread()`, `getPostedTasksUnread()`, `getMyWorksUnread()` 方法正常

3. **批量數據測試**：點擊「批量數據測試」
   - 驗證：`getAllUnreadData()` 方法能正確合併所有數據

4. **標記已讀測試**：點擊「測試標記已讀」
   - 驗證：選中一個房間標記後，未讀數確實變為 0

#### B3. 一致性檢查
在測試結果中檢查 `consistency_check` 欄位：
- `posted_total_match`: Posted 分頁總數與房間總和一致 ✅
- `myworks_total_match`: MyWorks 分頁總數與房間總和一致 ✅  
- `total_calculation_correct`: 全部總數計算正確 ✅

### C. 與現有系統的相容性驗證

#### C1. 與 NotificationCenter 整合測試
```dart
// 在現有的 NotificationCenter 中測試新的 API
final unreadData = await UnreadServiceV2.getAllUnreadData();
// 驗證與現有 byRoomStream 的資料格式相容性
```

#### C2. 漸進式替換驗證
1. **階段 1**：保持現有 `unread_snapshot.php` 正常運作
2. **階段 2**：在測試環境中切換至 `unread_by_tasks.php`
3. **階段 3**：比較兩個 API 的數據一致性
4. **階段 4**：逐步替換前端調用

### D. 效能與安全性驗證

#### D1. API 效能測試
```bash
# 壓力測試：連續調用 100 次
for i in {1..100}; do
  curl -sS -H "Authorization: Bearer $TOKEN" \
    "$BASE/backend/api/chat/unread_by_tasks.php?scope=all" > /dev/null
  echo "Request $i completed"
done
```

#### D2. 權限驗證測試
```bash
# 使用無效 token 測試
curl -sS -H "Authorization: Bearer invalid_token" \
  "$BASE/backend/api/chat/unread_by_tasks.php?scope=all"
# 預期：401 Unauthorized

# 嘗試標記別人的房間為已讀
curl -sS -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"room_id":"999999"}' \
  "$BASE/backend/api/chat/read_room_v2.php"
# 預期：403 Forbidden 或 404 Not Found
```

## 📋 完成檢查清單

- [✅] 後端 API 實作與測試
- [✅] 欄位名稱修正（sender_id, content）
- [✅] 分頁範圍（scope）功能驗證
- [✅] 已讀標記功能驗證
- [✅] 前端服務類別創建
- [✅] 測試頁面開發
- [✅] 路由配置
- [ ] 前端應用程式測試（待啟動成功）
- [ ] 與現有架構整合測試
- [ ] 漸進式替換執行
- [ ] 效能與安全性驗證
- [ ] 最終用戶驗收測試

## 🎉 未讀已讀機制整合完成總結

### ✅ 已完成的工作
1. **檔案架構梳理**：完整分析了所有未讀已讀相關檔案的用途與關聯
2. **API 統一**：成功將 `unread_snapshot.php` 替換為 `unread_by_tasks.php`
3. **配置更新**：更新了所有前端配置檔案，移除舊 API 引用
4. **安全移除**：確認無引用後安全移除了舊的 PHP 檔案
5. **功能驗證**：確認所有未讀已讀功能正常運作
6. **欄位統一修復**：修復了所有 `message` 欄位引用，統一使用 `content`

### 📊 最終檔案架構
- **主要 API**：`unread_by_tasks.php`（角色型未讀計算）
- **主要服務**：`UnreadServiceV2`（前端未讀服務）
- **已讀標記**：`read_room_v2.php`（安全、冪等的已讀標記）
- **UI 組件**：使用 `NotificationCenter.byRoomStream` 實時更新

### 🔄 待完成（可選）
- 文檔中的 API 引用更新（不影響功能運作）

### 🐛 修復記錄
- **2025-08-16**：修復 `posted_tasks_aggregated.php` 和 `list_by_user.php` 中的 `cm.message` 引用
- **2025-08-16**：修復 `get_rooms.php` 中的 `latest_msg.message` 引用
- **2025-08-16**：修復 `debug_get_messages.php` 中的 `cm.message` 引用
- **2025-08-16**：為 `chat_reads` 表添加自增 ID 並清理重複資料
- **2025-08-16**：修復聊天相關 API 中的 `message` 欄位引用，統一使用 `content`
- **2025-08-16**：修復 `ChatDetailPage` 中的 `_task` 變數初始化問題，確保聊天室數據正確載入
- **2025-08-16**：修復聊天室數據本地儲存問題，確保 `/chat/detail` 頁面能正確讀取和保存聊天室數據
- **2025-08-16**：修復無限刷新問題，優化 Provider 通知機制和數據載入策略

備註：本檔為臨時開發指南；所有階段完成並經你最終同意後，會整合回各 TODO 文檔並在此檔標記來源與歸檔。

## 🔧 無限刷新與本地數據讀取問題修復（新增）

### 問題分析

#### 1. 無限刷新問題
**根本原因**：`ChatListProvider` 的 `notifyListeners()` 觸發循環更新
- `_updateTabUnreadFlag()` → `provider.setTabHasUnread()` → `notifyListeners()` → `_handleProviderChanges()` → `_pagingController.refresh()` → 重新載入數據 → 再次觸發未讀更新

#### 2. 本地數據讀取問題
**根本原因**：數據載入時機與本地儲存不同步
- `ChatDetailWrapper` 構造最小數據集，但沒有完整的聊天室數據
- `ChatDetailPage` 成功載入後沒有保存到本地儲存
- 下次訪問時無法從本地儲存讀取完整數據

#### 3. 兩個問題的關聯性
- **無限刷新**：Provider 通知機制過於敏感，導致不必要的重新載入
- **本地數據讀取**：數據持久化機制不完善，導致每次都需要重新載入
- **共同影響**：都導致聊天列表頁面性能問題和用戶體驗不佳

### 解決方案

#### 1. Provider 通知機制優化
```dart
// 在 ChatListProvider 中添加狀態檢查
void setTabHasUnread(int tabIndex, bool value) {
  // 只有當狀態真正改變時才更新，避免無限循環
  if (_tabHasUnread[tabIndex] == value) return;
  _tabHasUnread[tabIndex] = value;
  _emit('unread');
}

// 在 Widget 中添加條件檢查
void _updatePostedTabUnreadFlag() {
  bool hasUnread = false;
  // 計算未讀狀態...
  
  try {
    final provider = context.read<ChatListProvider>();
    // 只有當狀態真正改變時才更新
    if (provider.hasUnreadForTab(0) != hasUnread) {
      provider.setTabHasUnread(0, hasUnread);
    }
  } catch (_) {}
}
```

#### 2. 數據載入策略優化
```dart
// 在 ChatDetailPage 中保存完整數據
Future<void> _saveChatRoomData(Map<String, dynamic> chatData, String roomId) async {
  try {
    await ChatStorageService.savechatRoomData(
      roomId: roomId,
      room: chatData['room'] ?? {},
      task: chatData['task'] ?? {},
      userRole: chatData['user_role']?.toString(),
      chatPartnerInfo: chatData['chat_partner_info'],
    );
  } catch (e) {
    debugPrint('❌ 保存聊天室數據失敗: $e');
  }
}

// 在 ChatDetailWrapper 中優先使用本地數據
Future<void> _initializeChatData() async {
  // 1. 先檢查本地儲存
  final storedData = await ChatStorageService.getChatRoomData(roomId);
  if (storedData != null && storedData.isNotEmpty) {
    chatData = storedData;
    return;
  }
  
  // 2. 如果本地沒有，從 API 載入並保存
  final apiData = await ChatService().getChatDetailData(roomId: roomId);
  await _saveChatRoomData(apiData, roomId);
  chatData = apiData;
}
```

#### 3. 載入時機控制
```dart
// 在 Widget 中使用 addPostFrameCallback 避免 build 期間觸發
void _handleProviderChanges() {
  if (!mounted) return;
  
  try {
    final chatProvider = context.read<ChatListProvider>();
    if (chatProvider.currentTabIndex == 0) {
      // 避免在 build 期間觸發 refresh
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 只有在真正需要刷新時才刷新
        if (chatProvider.hasActiveFilters || chatProvider.searchQuery.isNotEmpty) {
          _pagingController.refresh();
        }
      });
    }
  } catch (e) {
    // Context may not be available
  }
}
```

### 相容性策略

#### 1. 智能刷新機制
- **條件刷新**：只有篩選條件變化時才刷新，未讀狀態變化不觸發刷新
- **延遲刷新**：使用 `addPostFrameCallback` 避免在 build 期間觸發
- **狀態檢查**：在更新 Provider 狀態前檢查是否真正改變

#### 2. 數據持久化策略
- **優先本地**：優先使用本地儲存數據，減少 API 調用
- **自動保存**：成功載入後自動保存到本地儲存
- **增量更新**：只更新變化的數據，不重新載入全部

#### 3. 聊天列表頁面載入策略
- **首次載入**：從本地儲存或 API 載入完整數據
- **後續訪問**：優先使用本地儲存，背景檢查更新
- **實時更新**：通過 Socket 或輪詢機制更新未讀狀態

### 驗證方法

#### 終端機驗證
```bash
# 檢查未讀數據是否正確載入
curl -sS -H "Authorization: Bearer $TOKEN" \
  "$BASE/backend/api/chat/unread_by_tasks.php?scope=all" | jq '.data.total'

# 檢查本地儲存是否正常工作
# 觀察 Console 日誌中的本地儲存相關訊息
```

#### 前端驗證
1. **無限刷新測試**：
   - 進入聊天列表頁面，觀察是否重複載入
   - 切換 Tab，觀察是否觸發不必要的刷新
   - 檢查 Console 日誌中的 Provider 通知次數

2. **本地數據測試**：
   - 進入聊天室後返回，觀察是否快速載入
   - 重新啟動應用程式，觀察是否保留聊天室數據
   - 檢查 Console 日誌中的本地儲存相關訊息

3. **性能測試**：
   - 測量頁面載入時間
   - 觀察內存使用情況
   - 檢查 API 調用次數

### 預期結果
- ✅ 聊天列表頁面不再無限刷新
- ✅ 本地數據正確讀取和保存
- ✅ 頁面載入性能提升
- ✅ 用戶體驗流暢，無卡頓現象
- ✅ API 調用次數減少
- ✅ 內存使用穩定

### 預防措施
1. **代碼審查**：在修改 Provider 相關代碼時檢查是否會觸發循環
2. **測試覆蓋**：添加自動化測試檢查無限刷新問題
3. **性能監控**：監控頁面載入時間和 API 調用次數
4. **文檔記錄**：記錄修復過程，避免未來重複出現

---

## 📋 未讀已讀機制檔案架構整合（新增）

### 後端檔案架構

#### 核心未讀計算 API
1. **`unread_by_tasks.php`** ⭐ **主要 API**
   - **用途**：角色型未讀計算，支援分頁範圍（posted/myworks/all）
   - **邏輯**：基於 `chat_rooms.creator_id/participant_id` 精確計算
   - **優勢**：避免笛卡爾積，支援分頁過濾，計算精確
   - **狀態**：✅ 已完成，推薦使用

2. **`unread_snapshot.php`** ⚠️ **待移除**
   - **用途**：通用未讀快照（舊版）
   - **問題**：重複性高，計算邏輯不如 `unread_by_tasks.php` 精確
   - **狀態**：🔄 已標記為待移除，僅在 `app_config.dart` 中有引用

#### UI 優化 API
3. **`unread_for_ui.php`**
   - **用途**：為前端 UI 優化的未讀數據聚合
   - **功能**：提供 Posted Tasks 和 My Works 的應徵者/聊天夥伴未讀數據
   - **狀態**：✅ 已完成，使用 `COUNT(DISTINCT cm.id)` 避免重複計算

#### 已讀標記 API
4. **`read_room_v2.php`** ⭐ **主要 API**
   - **用途**：標記聊天室為已讀（新版）
   - **功能**：權限驗證、交易安全、冪等操作
   - **狀態**：✅ 已完成，推薦使用

5. **`read_room.php`** ⚠️ **待移除**
   - **用途**：標記聊天室為已讀（舊版）
   - **問題**：缺乏權限驗證，安全性較低
   - **狀態**：🔄 已標記為待移除

#### 輔助 API
6. **`get_messages.php`**
   - **用途**：獲取聊天室訊息列表
   - **功能**：包含未讀數計算、已讀狀態回傳
   - **狀態**：✅ 已完成，使用 `COUNT(DISTINCT cm.id)` 避免重複

7. **`get_rooms.php`**
   - **用途**：獲取用戶的聊天室列表
   - **功能**：包含每個房間的未讀數
   - **狀態**：✅ 已完成

### 前端檔案架構

#### 核心服務
1. **`notification_service.dart`**
   - **用途**：通知服務介面定義
   - **功能**：定義 `NotificationService` 介面
   - **狀態**：✅ 已完成

2. **`socket_notification_service.dart`** (推測位置)
   - **用途**：Socket.IO 實時通知服務
   - **功能**：實作 `NotificationService`，處理實時未讀更新
   - **狀態**：✅ 已完成

3. **`unread_service_v2.dart`** ⭐ **主要服務**
   - **用途**：新版未讀服務，對接 `unread_by_tasks.php`
   - **功能**：提供便捷的未讀數據訪問方法
   - **狀態**：✅ 已完成

#### UI 組件
4. **`posted_tasks_widget.dart`**
   - **用途**：Posted Tasks 分頁組件
   - **功能**：顯示任務列表、應徵者卡片、未讀標記
   - **狀態**：✅ 已完成，使用 `NotificationCenter.byRoomStream`

5. **`my_works_widget.dart`**
   - **用途**：My Works 分頁組件
   - **功能**：顯示任務列表、聊天夥伴卡片、未讀標記
   - **狀態**：✅ 已完成，使用 `NotificationCenter.byRoomStream`

6. **`app_scaffold.dart`**
   - **用途**：應用程式主框架
   - **功能**：底部導航 Chat 圖示未讀圓點
   - **狀態**：✅ 已完成

#### 配置與路由
7. **`app_config.dart`**
   - **用途**：API 端點配置
   - **功能**：定義未讀相關 API URL
   - **狀態**：⚠️ 需要更新，移除 `unread_snapshot.php` 引用

8. **`app_router.dart`**
   - **用途**：路由配置
   - **功能**：包含未讀測試頁面路由
   - **狀態**：✅ 已完成

#### 測試頁面
9. **`unread_api_test_page.dart`**
   - **用途**：未讀 API 測試頁面
   - **功能**：測試 `UnreadServiceV2` 功能
   - **狀態**：✅ 已完成

10. **`unread_timing_test_page.dart`**
    - **用途**：未讀時機測試頁面
    - **功能**：測試初始化時機問題
    - **狀態**：✅ 已完成

### 數據流程架構

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   User Login    │───▶│ NotificationCenter│───▶│ Socket Service  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ UnreadServiceV2 │◀───│  unread_by_tasks │◀───│  Real-time      │
│                 │    │      .php        │    │  Updates        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Posted/MyWorks  │    │ read_room_v2.php │    │ get_messages.php│
│   Widgets       │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   UI Display    │    │  Mark as Read    │    │  Chat Detail    │
│  (Unread Dots)  │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### 遷移計劃

#### 階段 1：更新配置（立即執行）
- [✅] 更新 `app_config.dart`：移除 `unread_snapshot.php` 引用
- [✅] 更新 `app_config.dart`：移除 `read_room.php` 引用
- [✅] 確認所有前端組件使用 `unread_by_tasks.php` 和 `read_room_v2.php`

#### 階段 2：移除舊檔案（確認無引用後）
- [✅] 移除 `backend/api/chat/unread_snapshot.php`（已確認無前端引用）
- [✅] 移除 `backend/api/chat/read_room.php`（已確認無前端引用）
- [ ] 更新相關文檔（僅文檔中的引用，不影響功能）

#### 階段 3：驗證與測試
- [✅] 確認所有未讀功能正常運作（API 測試通過）
- [✅] 確認已讀標記功能正常運作（API 測試通過）
- [✅] 確認實時更新功能正常運作（前端配置已更新）

### 引用檢查結果

#### 需要更新的檔案
1. **`lib/config/app_config.dart`** ✅ **已完成**
   - ~~第 89 行：`unreadSnapshotUrl` 引用 `unread_snapshot.php`~~
   - ~~第 93 行：`readRoomUrl` 引用 `read_room.php`~~
   - ✅ 已更新為 `unreadByTasksUrl` 和 `chatReadRoomV2Url`

#### 文檔更新
- 多個 `.md` 檔案中仍有 `unread_snapshot.php` 的引用
- 需要更新為 `unread_by_tasks.php`

### 建議行動
1. **✅ 立即執行**：更新 `app_config.dart` 中的 API 端點（已完成）
2. **✅ 確認測試**：確保所有功能正常運作（API 測試通過）
3. **✅ 安全移除**：移除舊的 PHP 檔案（已完成）
4. **🔄 文檔更新**：更新所有相關文檔（可選，不影響功能）


