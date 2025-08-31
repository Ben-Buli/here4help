# 管理員後台 MVP 規格文件（v1）

本文件整合以下三份來源文件與你在第 5 點給定的決策：
- 0831_管理員後台需求說明.md
- 0831客服聊天室模組.md
- 0831_資料庫現有架構.sql

並據此給出：系統範疇、資料模型、API 設計、前後端落地計畫（分期）、缺漏與決策點的最小集合。

開發原則
接下來只做規格文件中的事，不要額外執行其他工作，並且確保完成後都有檢查是否有 Problem錯誤會導致專案壞掉或無法執行，沒有影響性錯誤才算完成
flutter 前端元件請確保符合RWD 或是有避免溢出導致錯誤的風險


---

## 0. 決策彙總（已確認）
- Support 事件表：採用 support_events + chat_rooms（雙表，報表/索引友善）
- Dispute：採用 dispute_cases + chat_rooms（雙表，審計友善）
- Referral 可視化與發放時機：使用者 permission=1（審核通過）時立即發放 500 點
- Logs 細節：採 admin_logs 與 user_active_log 的最小事件集合（如下第 6 節）
- 倒數自動撥款：使用 cPanel cron（文件已有模板），每 10 分鐘掃描 pending_confirmation 到期案件

---

## 1. 範疇（MVP）
- Users 模組：列表、詳細、審核批准（permission 0→1）、停用/軟刪除、基本日誌
- Referral 模組：註冊輸入推薦碼 → 綁定到 referral_codes.used_by_user_id；批准（permission=1）即刻發 500 點（寫入 users.points + 註記 referral_codes.awarded_at）
- Support 模組：支援一案一房（support_events + chat_rooms），列表（All / Support / Dispute）、Claim/Transfer/Resolve 流程
- Dispute 模組：由任務房發起，建立 dispute_cases + chat_room；管理員 Claim/Resolve/Reject
- Payment 模組：入點數審核（approve/reject + 記帳）、手續費設定唯一 active、官方銀行帳戶唯一 active
- Tasks 模組：基本列表/詳細，顯示 pending 倒數資訊（實際自動撥款交給 cron）

---

## 2. 資料模型（MVP）

### 2.1 Users / Referral
- users
  - 重要欄位：id, name, email, permission(0/1/99/-2/-4), status(active/pending_review/...), points, referral_code(unique)
- referral_codes（單表管理）
  - 欄位：id, user_id(擁有者), referral_code(unique), is_used(tinyint, 可保留但不再使用), used_by_user_id(被誰引用), created_at, updated_at, awarded_at(NULLable)
  - 流程：
    - 註冊時引用 → 僅寫 used_by_user_id
    - 審核 permission=1 → 立即 users.points += 500 並寫 awarded_at=NOW()

### 2.2 Support / Dispute
- chat_rooms：type('support','dispute','task'), status('open','in_progress','waiting_customer','resolved','closed'), assignee_admin_id
- support_events：用戶向客服送出的一張票；索引/報表用
- dispute_cases：針對任務的爭議個案（開案/審理/結案）；配 chat_room

### 2.3 Payment / 設定
- point_deposit_requests：入點數審核
- point_transactions：記帳（earn/spend/deposit/fee/refund/...）
- fee_revenue_ledger：任務完成手續費收入
- task_completion_points_fee_settings：唯一 active
- official_bank_accounts：唯一 active

---

## 3. 後端 API 設計（MVP）

### 3.1 Users（/api/admin）
- GET /users?status=&permission=&search=&sort_by=&sort_order=&page=&per_page=
- GET /users/{id}
- PATCH /users/{id}/permission  body:{permission, reason}
  - 0→1：
    - 生成 users.referral_code（若沒有）
    - 在 referral_codes 找到 used_by_user_id={id} 且 awarded_at IS NULL → 設 awarded_at=NOW()，並對 users.points += 500
- PATCH /users/{id}/status body:{status, reason}
- POST /users/batch-action body:{action, user_ids[], reason}

### 3.2 Referral（/api/referral, /api/auth）
- POST /auth/verify-referral-code  body:{referral_code}
  - 檢查推薦碼擁有者：status ∈ {active,verified} 且 permission>0
- POST /referral/use-referral-code body:{referral_code, user_id}
  - 僅在 referral_codes 綁定 used_by_user_id；若已有，回錯
- GET /referral/list ...（可 Phase 2）
- GET /referral/get-referral-code（已修正參數順序並放寬為有效用戶）

### 3.3 Support（Admin 與 App 端）
- Admin 端：
  - GET /support/issues?type=all|support|dispute&status=...
  - POST /support/issues/{id}/accept（claim）
  - POST /support/issues/{id}/transfer
  - POST /support/issues/{id}/status（in_progress / waiting_customer / resolved / closed）
- App 端（目前需新增）：
  - GET /support/issues（回傳「我的」客服事件清單；含 room_id、type、status、未讀數、最後訊息時間）
  - GET /support/issues/{roomId}（單房事件詳情，供 IssueStatusPage 使用）
  - 可選：GET /chat/rooms?type=support|dispute（若沿用現有 chat API）

### 3.4 Dispute（/api/disputes）
- POST /disputes（body: task_id, description）→ 建 dispute_cases + chat_room(type='dispute') + 改任務狀態（若需要）
- POST /disputes/{id}/accept
- POST /disputes/{id}/resolve
- POST /disputes/{id}/reject

### 3.5 Payment（/api/admin/payment）
- GET /payment/requests
- POST /payment/requests/{id}/approve  → users.points += amount, point_transactions 新增
- POST /payment/requests/{id}/reject
- GET/POST /payment/fee-settings（唯一 active）
- GET/POST /payment/official-accounts（唯一 active）

---

## 4. 前端（Admin Vue）路由與頁面
- /login（token 登入）
- /dashboard（卡片：待審 users、待審入點數、客服 ticket 數）
- /users（列表）
- /users/:id（詳細 + 批准/停用/軟刪除 + 學生證圖片與基本日誌）
- /issues（列表；Tabs: All/Support/Dispute；可點進聊天室）
- /payments/requests（入點數審核）
- /payments/settings（手續費設定、官方帳戶）

---

## 5. Flutter App 配合（落差待補）

### 5.1 新增路由
- /account/support/issues：我的客服事件列表（support/dispute；可 Tab 或篩選）
- /account/support/chat/:roomId：客服聊天室（沿用 ChatDetail，對 type 做分支）

### 5.2 IssueStatusPage 擴充
- 行為調整：
  - 若有 chatRoomId → 以 API 取得該房事件流（現有雛形 `SupportEventApi.getEvents`）
  - 若無 chatRoomId → 改為載入「我的客服事件清單」模式（非僅顯示舊版單筆靜態 UI）；保留舊版 UI 作為 fallback（可在頁內切換）
- 篩選器：all/open/in_progress/resolved/closed_by_customer（已存在，可沿用）

### 5.3 對接 API
- GET /support/issues（清單）
- GET /support/issues/{roomId}（單房事件）
- 可選：GET /chat/rooms?type=support|dispute（沿用現有 chat API）

---

## 6. Logs 最小集合（MVP）
- admin_logs（建議欄位）：id, admin_id, action, target_type, target_id, changes(json), created_at
  - 事件：update_user_permission, update_user_status, support_claim, support_transfer, support_resolve, dispute_accept, dispute_resolve, dispute_reject, payment_approve, payment_reject, fee_setting_update, bank_account_set_active
- user_active_log：id, user_id, actor_type(user|admin|system), actor_id, action, field, old_value, new_value, reason, created_at
  - 事件：register, verify_completed, permission_change(0→1), status_change

---

## 7. 分期落地計畫
- Phase 1（2 週）
  - Admin 前端基礎框架：登入、Layout、路由
  - Users 模組（列表/詳細/批准）
  - Referral 流程全串（verify/use/批准發點）
  - 最小 logs 寫入（permission/status 變更）
  - Flutter：新增 /account/support/issues 與 /account/support/chat/:roomId，擴充 IssueStatusPage
- Phase 2（2~3 週）
  - Support/Dispute 列表與基本流（Claim/Transfer/Resolve/聊天室權限）
  - Payment：requests 審核、fee settings、官方帳戶
- Phase 3（2 週）
  - Tasks 詳細 + pending 倒數顯示
  - Logs/Reports 基礎

---

## 8. Cron 與自動化（cPanel）
- 每 10 分鐘：掃描 tasks.status='pending_confirmation' 且 deadline<=NOW() → 觸發自動撥款（轉帳/扣費/記帳/狀態改 completed）
- 於 cPanel 設置 cron，並確保 API/Script 有權限寫 logs

---

## 9. 風險與備註
- referral_codes 耦合「引用」「發放」：以 used_by_user_id 與 awarded_at 區隔，避免 is_used 語意混淆
- support/dispute 聊天室權限：assignee 管理員才能發言；其他管理員 read-only
- 生產環境 CORS/HTTPS：請統一改 https 並確保前端 baseURL 正確

---

## 10. 待你確認清單 （同意）
- 本文件第 0 節決策是否完全同意(同意)
- 第 3 節 API 命名與路徑是否有要調整（同意）
- 第 7 節分期時程（Phase 1 起跑）（同意）

（同意後，我會建立對應的 issue/todos，依 Phase 1 開始實作 Users + Referral 全串接。）
