### Chat Detail Action Bar — 完整邏輯清單（現實作為準）

#### 角色與狀態
- 角色：creator（任務發布者）、participant（接案者）
- 任務狀態代碼（`task_statuses.code`）：open / in_progress / pending_confirmation / completed / dispute / cancelled / rejected

#### 動作對應（依狀態 × 角色）
- open
  - creator：Accept（改為 application accept 流程：指派 `tasks.participant_id = user_id`，該應徵 `accepted`，其餘 `rejected`）；可選：Cancel Task（可加在 chat/detail）
  - participant：Withdraw Application（可加按鈕，呼叫 `applications/update-status.php`）
- in_progress
  - creator：Raise Dispute（`/backend/api/tasks/dispute.php`）；可選：Mark Done（改 pending_confirmation）
  - participant：Completed（改 pending_confirmation）
- pending_confirmation
  - creator：
    - Confirm（同意完成；計算手續費，完成點數轉移與狀態更新）
    - Disagree（駁回：改回 in_progress，寫入 user_active_log 並送出系統訊息）
    - Report
  - participant：Report、Dispute（如需求）
- completed / dispute / cancelled / rejected
  - 通用：Report（僅在 open、cancelled、rejected 顯示 Block；其他執行過程狀態一律使用 Dispute 流，dispute 狀態由管理員介入處理）；creator 在 completed 可看 Paid/Reviews（現 UI 已有）

#### 後端端點（關鍵）
- 更新狀態（通用）：`backend/api/tasks/update.php`（支援 `status_code` 或 `status_id`）
- 申訴：`backend/api/tasks/dispute.php`
- 同意完成：`backend/api/tasks/confirm_completion.php`
  - 輸入：`task_id`
  - 行為：
    - 讀取費率：`task_completion_points_fee_settings WHERE isActive=1`，欄位 `rate DECIMAL(5,4)`（0.02 表示 2%）
    - 計算：`amount = tasks.reward_point`；`fee = amount * rate`；`net = amount - fee`
    - 點數轉移與交易記錄（見下）
    - 更新狀態：`completed`（以 `task_statuses` 查 id，fallback 文字欄位）
    - 系統訊息：僅當前房間發送 `kind='system'` 的費用摘要
  - 回傳：`{ task, fee_rate, fee, amount, net }`
  - 支援 preview：傳入 `preview=1` 時只回傳試算（不改狀態、不寫交易、不發訊息）
- 駁回完成：`backend/api/tasks/disagree_completion.php`
  - 輸入：`task_id`, `reason`
  - 行為：將 `pending_confirmation → in_progress`；寫入 `user_active_log`；僅當前房間發送 `kind='system'` 駁回訊息（含理由）
- 指派應徵（新增規劃）：`backend/api/tasks/applications/accept.php`（新）
  - 輸入：`task_id`, `application_id`（或 `user_id`）, `poster_id`
  - 行為：`tasks.participant_id = user_id`；該 `task_applications` 設為 `accepted`，其餘 `rejected`；僅當前房間送出 `kind='system'` 指派訊息
- Applications 狀態更新：`backend/api/tasks/applications/update-status.php`

#### 點數轉移與交易記錄（以你提供為準）
- 拆分：`rwd_pt = tasks.reward_point`（文件內部沿用欄位名 `reward_point`；如資料庫使用 `reward_points`，需統一）
- 扣款主體：`tasks.creator_id`
- 交易（皆為 creator 的支出）
  1) 支出 `rwd_pt`（任務獎勵）
  2) 支出 `rwd_pt * rate`（手續費）
- 記錄：
  - 每次任務完成成功後，寫入 `user_active_log` 兩筆支出紀錄（action 固定：`task_completion_reward`、`task_completion_fee`；建議 `metadata` JSON 含 `{task_id, amount, fee, net, rate}` 與交易說明）
  - 之後如有 `point_transactions` 錢包表，也同步寫入（待錢包模組決議）
- 狀態：點數轉移與記錄成功後，`tasks.status_id = 5 (completed)`（或以 `task_statuses` 決定為準）

#### 前端互動（重點）
- Disagree（駁回）：彈出理由輸入框 → 呼叫 `TaskService.disagreeCompletion(taskId, reason)`
- Confirm（同意完成）：先呼叫 `confirm_completion`（`preview=1`）取得試算 → 顯示「金額/費率/淨額」於 Dialog → 使用者確認後再呼叫正式 `confirm_completion`（不帶 preview）執行

### 已落實的變更（後端）
- `backend/api/tasks/disagree_completion.php`：
  - 驗證身份 → 將狀態改回 `in_progress`（以 code 查 id）→ 寫入 `user_active_log`（`action='disagree_completion'`）→ 發送 `kind='system'` 系統訊息（含理由）
- `backend/api/tasks/confirm_completion.php`：
  - 驗證身份 → 讀取費率表 `task_completion_points_fee_settings`（`rate DECIMAL(5,4)`；`isActive=1`）→ 計算 `amount/fee/net` → （正式確認）狀態改為 `completed`（以 code 查 id）→ 僅當前房間發送 `kind='system'` 系統訊息（顯示費用）→ 回傳 `task, fee_rate, fee, amount, net`；支援 `preview=1`

### 待決策 / 需補充（殘留）
- 駁回理由 validation：是否必填（建議必填）、長度上限（建議 ≤300）、敏感字清理規則
- 伺服端欄位名統一：若有 `tasks.reward_points` 與 `tasks.reward_point` 混用，需最終對齊（本文件以 `reward_point` 為準）
- confirm_completion 後端程式碼需對齊費率表名稱與欄位（`task_completion_points_fee_settings.rate`）

### TODO（實作追蹤）
- [ ] 前端：新增「駁回完成」理由輸入 Dialog，串 `disagreeCompletion(taskId, reason)`
- [ ] 前端：新增「同意完成」二次確認 Dialog（先 preview，再 confirm），顯示金額/費率/淨額
- [ ] 後端：`confirm_completion.php` 補上「實際點數轉移」與 `user_active_log` 兩筆交易（`task_completion_reward`、`task_completion_fee`）
- [x] 後端：`confirm_completion.php` 支援 `preview=1` 返回試算（不改狀態、不寫交易、不發訊息）
- [ ] 前端：chat/detail 顯示回傳之費率與金額摘要（SnackBar 或系統訊）
- [ ] 後端：新增 `backend/api/tasks/applications/accept.php`（設定 participant、更新應徵狀態、送出系統訊息至當前 room）
- [ ] 前端：調整 chat/detail 的「Accept」改呼叫 applications/accept 流程
- [ ] 前端：在 chat/detail 加入 Cancel Task（若確定要）
- [ ] 文件：對齊狀態代碼與拼字，統一 `status_code` 與 `cancelled`
- [ ] 後端：`confirm_completion.php` 改為讀取 `task_completion_points_fee_settings.rate`（目前程式需對齊表名/欄位）
- [ ] 後端：Disagree 理由驗證規則（必填/長度/清理）

### user_active_log 規格與寫入映射（Action Bar 全覆蓋）

#### 命名與慣例
- actor_type：一律 `user`
- actor_id：操作者的 `users.id`
- user_id：被影響的主體。若為操作者自身行為（多數情況）= actor_id。若需記錄另一名用戶（例如對方被封鎖），在單獨一筆中以被影響者為 user_id（可採雙筆策略，視需要）
- field：有明確欄位變更時填入（如 `status`、`participant_id`、`application.status`），否則為 NULL
- old_value/new_value：若能取得變更前後值則填入，否則為 NULL
- reason：若操作有理由（駁回、申訴等）則寫入；前端應限制長度（建議 ≤300）並做敏感字/HTML 清理
- metadata（JSON）：標準鍵集合，按需擴充
  - 常用鍵：`task_id`, `application_id`, `room_id`, `rate`, `amount`, `fee`, `net`, `rejected_application_ids`（陣列）, `target_user_id`, `dispute_id`

#### 標準化 action 名稱
- application_accept：指派應徵者
- application_reject_bulk：同任務批次拒絕其他應徵（或以陣列記錄）
- application_withdraw：應徵者撤回
- task_mark_done_request：接案者提交完成（送審）
- disagree_completion：發布者駁回完成
- task_completion_reward：發布者支出任務獎勵（完成時）
- task_completion_fee：發布者支出任務手續費（完成時）
- task_cancel：發布者取消任務
- task_dispute_create：建立爭議
- chat_report_submit：送出檢舉
- user_block：封鎖用戶

#### 各操作寫入規格

1) Accept（application accept 流程，creator）
```
action: application_accept
user_id: <creator_id>
actor_id: <creator_id>
field: participant_id
old_value: <先前 participant_id 或 NULL>
new_value: <被指派 user_id>
reason: NULL
metadata: {
  task_id, application_id, room_id,
  rejected_application_ids: [ ... ] // 若採批次拒絕方式
}
```
（若要額外記錄被拒者，可另寫一筆 application_reject_bulk，或逐一 application_reject）

2) Withdraw Application（participant）
```
action: application_withdraw
user_id: <participant_id>
actor_id: <participant_id>
field: application.status
old_value: applied
new_value: withdrawn
reason: <可選>
metadata: { task_id, application_id, room_id }
```

3) Mark Done（participant → pending_confirmation）
```
action: task_mark_done_request
user_id: <participant_id>
actor_id: <participant_id>
field: status
old_value: in_progress
new_value: pending_confirmation
reason: NULL
metadata: { task_id, room_id }
```

4) Disagree Completion（creator）
```
action: disagree_completion
user_id: <creator_id>
actor_id: <creator_id>
field: status
old_value: pending_confirmation
new_value: in_progress
reason: <駁回理由>
metadata: { task_id, room_id }
```

5) Confirm Completion（creator，正式確認時寫入兩筆）
```
// 支出獎勵
action: task_completion_reward
user_id: <creator_id>
actor_id: <creator_id>
field: points
old_value: NULL
new_value: NULL
reason: NULL
metadata: { task_id, amount: rwd_pt, rate, fee, net }

// 支出手續費
action: task_completion_fee
user_id: <creator_id>
actor_id: <creator_id>
field: points
old_value: NULL
new_value: NULL
reason: NULL
metadata: { task_id, amount: rwd_pt, fee: rwd_pt*rate, rate }
```
（注意：preview=1 不寫入 log）

6) Cancel Task（creator）
```
action: task_cancel
user_id: <creator_id>
actor_id: <creator_id>
field: status
old_value: <原狀態>
new_value: cancelled
reason: <可選>
metadata: { task_id }
```

7) Raise Dispute（creator 或 participant）
```
action: task_dispute_create
user_id: <actor_id>
actor_id: <actor_id>
field: status
old_value: <原狀態>
new_value: dispute
reason: <申訴理由>
metadata: { task_id, dispute_id }
```

8) Report（檢舉聊天）
```
action: chat_report_submit
user_id: <actor_id>
actor_id: <actor_id>
field: NULL
old_value: NULL
new_value: NULL
reason: <檢舉理由>
metadata: { room_id, task_id, evidence: [temp_names or urls] }
```

9) Block User（封鎖）
```
action: user_block
user_id: <actor_id>
actor_id: <actor_id>
field: NULL
old_value: NULL
new_value: NULL
reason: NULL
metadata: { target_user_id }
```

（一般聊天訊息 send_text/send_image 不建議逐筆寫入 user_active_log 以免造成雜訊，可由聊天系統本身的訊息表留存即可）


# Finish Logs
// 以下撰寫執行操作紀錄

## 2025-01-17 執行階段 1：前端 Dialog 實作

### ✅ 已完成項目

#### 1. 駁回完成理由輸入 Dialog
- **檔案**: `lib/chat/widgets/disagree_completion_dialog.dart`
- **功能**: 
  - 理由輸入框（必填，最大 300 字）
  - 字數計數器顯示
  - 提交時驗證理由不能為空
  - 載入狀態顯示
  - 錯誤處理與用戶反饋

#### 2. 同意完成二次確認 Dialog
- **檔案**: `lib/chat/widgets/confirm_completion_dialog.dart`
- **功能**:
  - 支援 preview 模式（先取得試算）
  - 顯示金額/費率/淨額詳細資訊
  - 二次確認機制
  - 載入狀態與錯誤處理
  - 重試機制

#### 3. TaskService 更新
- **檔案**: `lib/task/services/task_service.dart`
- **更新**: `confirmCompletion` 方法新增 `preview` 參數支援

#### 4. Chat Detail Page 整合
- **檔案**: `lib/chat/pages/chat_detail_page.dart`
- **更新**:
  - 導入新的 Dialog 組件
  - 更新 `_handleConfirmCompletion` 方法使用新的 Dialog
  - 更新 `_handleDisagreeCompletion` 方法使用新的 Dialog
  - 支援理由參數傳遞

#### 5. 後端費率表對齊
- **檔案**: `backend/api/tasks/confirm_completion.php`
- **更新**: 修正費率表名稱從 `task_completion_fee_setting` 改為 `task_completion_points_fee_settings`
- **更新**: 修正欄位名稱從 `fee_rate` 改為 `rate`

### 🔧 技術實作細節

#### Dialog 設計原則
- **用戶體驗優先**: 清晰的資訊展示和操作流程
- **錯誤處理**: 完整的錯誤狀態管理和用戶反饋
- **載入狀態**: 適當的載入指示器避免用戶困惑
- **驗證機制**: 前端驗證確保數據完整性

#### 整合架構
- **模組化設計**: Dialog 組件獨立，可重用
- **回調機制**: 使用函數回調處理用戶操作
- **狀態管理**: 正確的狀態更新和頁面刷新

### 📋 待完成項目

#### 資料庫初始化
- **問題**: 本地資料庫連接失敗
- **解決方案**: 需要啟動 MAMP 或配置資料庫連接
- **影響**: 費率設定無法初始化，但不影響前端功能測試

#### 後端點數轉移實作
- **狀態**: 待開始
- **依賴**: 資料庫連接正常後進行

### 🎯 下一步計劃

1. **解決資料庫連接問題**
2. **測試完整流程**
3. **進行 Application Accept 流程實作**

## 2025-01-17 執行階段 2：後端點數轉移實作

### ✅ 已完成項目

#### 1. 點數轉移與交易記錄實作
- **檔案**: `backend/api/tasks/confirm_completion.php`
- **功能**:
  - 完整的點數轉移邏輯（創建者支出 → 接案者收入）
  - 手續費計算與扣除
  - 使用 `PointTransactionLogger` 記錄所有交易
  - 同步更新 `fee_revenue_ledger` 手續費收入記錄
  - 寫入 `user_active_log` 兩筆支出紀錄
  - 原子化交易確保數據一致性

#### 2. PointTransactionLogger 修正
- **檔案**: `backend/utils/PointTransactionLogger.php`
- **修正**: SQL 查詢中缺少 `balance_after` 欄位的問題
- **功能**: 正確記錄交易後餘額

#### 3. Application Accept API 實作
- **檔案**: `backend/api/tasks/applications/accept.php`
- **功能**:
  - 驗證操作者為任務創建者
  - 更新任務狀態為 `in_progress`
  - 設定 `participant_id`
  - 更新應徵狀態（接受指定應徵，拒絕其他應徵）
  - 寫入 `user_active_log`
  - 發送系統訊息到聊天室

#### 4. 前端 TaskService 更新
- **檔案**: `lib/task/services/task_service.dart`
- **新增**: `acceptApplication` 方法
- **功能**: 呼叫新的 Application Accept API

#### 5. 前端 Chat Detail Page 整合
- **檔案**: `lib/chat/pages/chat_detail_page.dart`
- **更新**: `_handleAcceptApplication` 方法
- **功能**: 使用新的 API 流程，包含錯誤處理和用戶反饋

### 🔧 技術實作細節

#### 點數轉移流程
1. **創建者支出任務獎勵**（負數）
2. **接案者收入任務獎勵**（正數，扣除手續費）
3. **創建者支出手續費**（負數）
4. **記錄手續費收入**到 `fee_revenue_ledger`
5. **更新用戶點數餘額**
6. **寫入審計日誌**

#### 原子化交易
- 使用資料庫交易確保所有操作的一致性
- 任何步驟失敗都會回滾所有變更
- 錯誤處理不阻斷主流程

#### Application Accept 流程
- 驗證權限和狀態
- 批量更新應徵狀態
- 完整的審計記錄
- 系統訊息通知

### 📋 待完成項目

#### 資料庫連接問題
- **狀態**: 仍需要解決
- **影響**: 無法測試完整功能
- **解決方案**: 啟動 MAMP 或配置資料庫連接

#### 測試與驗證
- **狀態**: 待開始
- **依賴**: 資料庫連接正常後進行

### 🎯 下一步計劃

1. **解決資料庫連接問題**
2. **測試完整流程**

## 2025-01-17 執行階段 3：驗證規則與清理

### ✅ 已完成項目

#### 1. Disagree 理由驗證規則
- **檔案**: `backend/api/tasks/disagree_completion.php`
- **功能**:
  - 必填驗證：理由不能為空
  - 長度限制：最大 300 字
  - 內容清理：移除 HTML 標籤
  - 安全處理：HTML 實體編碼
  - 詳細錯誤訊息：區分不同驗證失敗情況

#### 2. 欄位名稱統一
- **檔案**: `backend/api/tasks/history.php`
- **修正**: 將 `reward_points` 統一為 `reward_point`
- **影響**: 確保與其他 API 的一致性

#### 3. 狀態代碼檢查
- **結果**: 系統中主要使用 `status_code`（下劃線）和 `cancelled`（英式拼法）
- **狀態**: 已確認一致性，無需修改

### 🔧 技術實作細節

#### 驗證規則設計
```php
// 必填驗證
if ($reason === '') {
  $errors['reason'] = 'required';
} elseif (strlen($reason) > 300) {
  $errors['reason'] = 'max_length_exceeded';
}

// 內容清理
$reason = strip_tags($reason);
$reason = htmlspecialchars($reason, ENT_QUOTES, 'UTF-8');
```

#### 欄位名稱統一原則
- **reward_point**: 使用單數形式（與其他 API 一致）
- **status_code**: 使用下劃線分隔（與資料庫設計一致）
- **cancelled**: 使用英式拼法（與系統慣例一致）

### 📋 待完成項目

#### 資料庫連接問題
- **狀態**: 仍需要解決
- **影響**: 無法測試完整功能
- **解決方案**: 啟動 MAMP 或配置資料庫連接

#### 測試與驗證
- **狀態**: 待開始
- **依賴**: 資料庫連接正常後進行

### 🎯 下一步計劃

1. **解決資料庫連接問題**
2. **測試完整流程**

## 2025-08-27 執行階段 4：資料庫連接與測試 ✅

### ✅ 已完成項目

#### 1. MAMP 資料庫連接問題解決
- **問題**: 資料庫連接失敗 `SQLSTATE[HY000] [2002] No such file or directory`
- **解決方案**: 使用 MAMP socket 連接 `/Applications/MAMP/tmp/mysql/mysql.sock`
- **結果**: 成功建立資料庫連接

#### 2. 費率表初始化
- **檔案**: `backend/scripts/init_fee_settings_simple.php`
- **檔案**: `backend/scripts/update_fee_rate.php`
- **功能**: 
  - 檢查並創建 `task_completion_points_fee_settings` 表
  - 設定預設 2% 手續費率
  - 驗證費率設定正確性

#### 3. 費率計算邏輯測試
- **檔案**: `backend/test/test_fee_calculation.php`
- **測試結果**: ✅ 成功
- **驗證內容**:
  - 100 點任務：手續費 2.00，淨額 98.00
  - 500 點任務：手續費 10.00，淨額 490.00
  - 1000 點任務：手續費 20.00，淨額 980.00
  - 2000 點任務：手續費 40.00，淨額 1960.00
  - 5000 點任務：手續費 100.00，淨額 4900.00

#### 4. 資料庫表結構驗證
- **檔案**: `backend/test/test_database_tables.php`
- **驗證結果**: ✅ 所有相關表存在且結構正確
- **確認表**:
  - `task_completion_points_fee_settings` (2 筆記錄)
  - `point_transactions` (5 筆記錄)
  - `fee_revenue_ledger` (0 筆記錄)
  - `user_active_log` (40 筆記錄)
  - `tasks` (88 筆記錄)
  - `task_statuses` (8 筆記錄)
  - `users` (22 筆記錄)
  - `chat_rooms` (75 筆記錄)
  - `chat_messages` (397 筆記錄)

#### 5. 欄位名稱一致性修正
- **問題**: `isActive` vs `is_active` 欄位名稱不一致
- **修正檔案**: 
  - `backend/api/tasks/confirm_completion.php`
  - `backend/test/test_fee_calculation.php`
- **結果**: 統一使用 `is_active`（下劃線格式）

### 🔧 技術實作細節

#### MAMP Socket 連接配置
```php
$dsn = "mysql:unix_socket=/Applications/MAMP/tmp/mysql/mysql.sock;dbname=hero4helpdemofhs_hero4help;charset=utf8mb4";
$pdo = new PDO($dsn, 'root', 'root', [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
]);
```

#### 費率計算驗證
```php
$feeRate = (float)$feeRow['rate']; // 0.0200 (2%)
$feeAmount = round($amount * $feeRate, 2);
$netAmount = max(0.0, $amount - $feeAmount);
```

### 📋 測試結果總結

#### ✅ 成功項目
- 資料庫連接正常
- 費率計算準確
- 所有相關表結構正確
- 欄位名稱一致性已修正
- 測試數據可用

#### 🔄 待測試項目
- 完整的 API 端到端測試
- 前端 Dialog 功能測試
- 點數轉移實際執行
- 系統訊息發送測試

### 🎯 下一步計劃

1. **進行完整的端到端測試**
2. **驗證前端 Dialog 功能**
3. **測試實際的點數轉移流程**
4. **確認系統訊息發送正常**