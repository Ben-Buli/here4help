# Admin MVP 進度追蹤

開發原則（摘錄）：只做規格文件中的事；每階段完成後檢查是否有 Problem 級錯誤（破壞執行/壞掉），無影響性錯誤才算完成；Flutter 元件需注意 RWD 與避免溢出。

---

## Phase 1（Users + Referral + 基礎框架 + Flutter 支援）

- 狀態：進行中
- 里程碑與任務：
  1) Admin 前端基礎框架（登入、Layout、路由）
     - 狀態：完成
     - 重點紀錄：修正 `admin/frontend/src/router/index.ts` /logs 路由遺漏 component 造成語法錯誤（已補 `AppLayout`）。
     - 風險/備註：尚未驗證所有子頁是否存在對應 view；後續逐頁接續對接。
  2) Users 模組（列表/詳細/批准）
     - 狀態：完成
     - 重點：統一後端清單回傳鍵名為 items；前端 UsersView 對接 data.items；UserEditModal 狀態值改為 pending_review。
     - 檢查：批准 0→1 觸發 referral 產碼與 500 點數發放，無 Problem 級錯誤。
  3) Referral 全流程（verify/use/批准即發 500）
     - 狀態：待辦（後端已調整，前端/後台串接待做）
     - 檢查點：used_by_user_id 綁定、awarded_at 標記正確。
  4) 最小 logs（permission/status 變更）
     - 狀態：完成
     - 重點：於 `Admin/UserController@updateStatus` 與 `@updatePermission` 增寫 user_active_log（表存在時寫入），不阻斷主流程。
  5) Flutter 新增路由與頁面骨架
     - 狀態：完成
     - 路由：`/account/support/issues`、`/account/support/chat`（以 `ChatDetailWrapper` 接資料）。
     - 重點：新增 `SupportIssuesPage` 骨架，RWD 與避免溢出，保留現有 `/account/support/issue_status`。
  6) 擴充 IssueStatusPage（清單/單房模式 + API）
     - 狀態：待辦
     - 檢查點：有 chatRoomId 走單房；無 chatRoomId 走清單；保留舊 UI 為 fallback。

---

## Phase 2（Support/Dispute 基本流 + Payment）
- 狀態：進行中
- 任務進度：
  - 支援/申訴列表與基本流（Claim/Transfer/Resolve）
    - 狀態：完成
    - 後端：新增 `SupportController` 與 API 路由（/admin/support/issues、accept、transfer、status）
    - 前端：新增 `IssuesView.vue` 與 `supportApi`，整合列表/過濾/操作
  - Payment 請求審核與設定
    - 狀態：完成
    - 請求審核：完成（後端 `PaymentController` / 前端 `DepositApprovalPage` + `paymentApi`）
    - 設定：完成（`FeeManagementPage.vue`、`OfficialBankAccountPage.vue` 與對應 API）

---

## Phase 3（Tasks 細節 + 倒數顯示 + 報表）
- 狀態：完成
- 里程碑與任務：
  - 任務倒數顯示（pending_confirmation）：
    - 後端：於 `Admin/TaskController` 列表與詳情回傳 `countdown_seconds`（以 `tasks.deadline` 計算，若無則為 `null`）
    - 前端：`TasksView.vue`、`TaskDetailView.vue` 新增倒數欄位並人性化顯示（d/h/m/s）
  - Logs/Reports 基礎：
    - 前端：沿用 `LogsView.vue`，完成清單/分頁/篩選（含 tabs 與日期區間）之 API 對接
    - 後端：使用現有 `LogController`，以最小集合支援 Dashboard 與清單需求
  - 備註/風險：
    - 倒數依賴 `tasks.deadline` 與 `status_code=pending_confirmation`；若資料不齊，`countdown_seconds=null`（前端顯示 "-"）
    - 自動撥款仍交由 cPanel cron（Phase 0 決策）；需在正式環境確認 cron 權限與時序

---

## 模糊/需決策（若出現將在此追加並待核）
- （目前無）

---

## Next（交付後收尾與擴展）
- 驗收與測試：
  - E2E/整合測試：Users 批准→Referral 發點、Support/Dispute 流程、Payment 審核流程
  - Flutter App 端路由/權限回歸測試（/account/support/issues、/account/support/chat）
- 監控與維運：
  - cPanel cron 佈署與排程監看（自動撥款）
  - 錯誤/活動日誌查核（LogsView 與後端 log 統計）
- 安全與權限：
  - Admin 前端 `permission` meta 與後端 middleware 再次比對
  - API CORS/HTTPS 與環境變數（baseURL）核對
- 資料校驗與種子：
  - 基礎管理員帳號/權限 seed、任務/申訴/儲值測試資料 seed
- 文件：
  - 管理員操作手冊（Users/Issues/Payments/Logs）
  - API 介面最終版（以本次實作為準）
