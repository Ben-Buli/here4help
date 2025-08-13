# Here4Help TODO - 快速索引

## 📊 專案狀態
- **完成度**: 52.3% (34/65 任務)
- **目標**: 7天內完成 100%
- **當前版本**: v1.2.4
- **下個版本**: v1.2.5 (任務狀態管理改善 / 聊天系統優化)

## 🎯 最新進展 (2025/1/18)
### ✅ v1.2.4 完成項目 - 專案結構清理優化
- **檔案清理**: 完整清理專案結構，提升開發效率
  - 移除 5 個根目錄測試檔案到 `tests/archived/`
  - 清除所有 `.DS_Store` 和 IntelliJ IDEA 檔案
  - 刪除 `backup/` 目錄及重複檔案
  - 更新 `.gitignore` 防止系統檔案再次出現
- **文件結構優化**: 建立分類目錄系統
  - 🗂️ `docs/guides/` - 操作指南 (7 個檔案)
  - 🗂️ `docs/reports/` - 系統報告 (2 個檔案)
  - 🗂️ `docs/analysis/` - 分析文件 (3 個檔案)
  - 🗂️ `docs/archive/` - 歷史文件 (5 個檔案)
  - 🗂️ `docs/chat/` - 聊天相關 (3 個檔案)
  - 🗂️ `docs/admin/` - 管理工具 (1 個檔案)
- **開發體驗**: 專案根目錄更加清潔，文件分類清晰

### ⚡ v1.2.3 完成項目 - 環境變數配置與功能驗證
- **環境變數系統建立**: 完整實作 `.env` 配置管理
  - 建立 `backend/config/env_loader.php` 類別
  - 設定 `backend/config/env.example` 範本
  - 修改 `backend/socket/server.js` 使用 dotenv
  - 新增 `.env` 到 `.gitignore` 確保安全
- **系統功能驗證**: 完整測試所有核心功能
  - 資料庫連線測試：20用戶+38任務+8狀態
  - API 端點驗證：7/7 端點正常回應
  - Socket.IO 服務測試：port 3001 正常運行
  - Flutter 應用測試：Web 版成功啟動
- **重要發現**: 任務狀態 API 已完全實作且可用
- **文件完善**: 新增 5 個系統文件和分析報告

### ⚡ v3.3.2 完成項目
- **聊天室數據完整性修復**: 修復 `ensure_room.php` API 中的 SQL 查詢，正確關聯用戶表並返回用戶資訊
- **資料庫結構同步**: 根據實際資料庫結構修復欄位名稱不一致問題（`name` vs `username`）
- **圖片預覽功能優化**: 
  - 修復圖片預覽關閉後空白畫面問題
  - 優化預覽按鈕位置（關閉按鈕左上角，下載按鈕右下角）
  - 使用 `showDialog` 和 `PopScope` 替代 `PageRouteBuilder` 解決導航衝突
- **聊天對手頭像修復**: 
  - 修復 `chat_list_page.dart` 中硬編碼預設頭像問題
  - 優化頭像獲取邏輯，過濾預設 assets 路徑，支援文字頭像
- **應徵者卡片數據映射**: 
  - 修復 `_convertApplicationsToApplierChatItems` 中的頭像數據映射
  - 添加詳細 debug 日誌追蹤數據流
- **聊天列表載入修復**: 修正 `/chat` 頁面應徵者卡片在 hot restart 和 web 刷新時消失的問題
- **載入狀態優化**: 實現 `_isInitialLoadComplete` 標記來追蹤真正的載入完成狀態
- **聊天訊息持久化**: 完成 `/chat/detail` 訊息保存到 `chat_messages`
- **Socket.IO 整合**: 建立即時聊天基礎架構，支援即時訊息接收/發送

## 🧭 Chat Detail Action Bar - 任務與進度

### 目標
- 模組化 Action Bar（可依 `creator/participant` 與任務狀態切換動作）
- Minimal UI 骨架先就緒；DB/API 第二步串接

### 已完成（前端骨架 / 第一步）
- 模組化 Action Bar：集中映射、依角色/狀態產生按鈕
- plus/photo 圖示：
  - plus：切換 Action Bar 顯示/隱藏
  - photo：先開啟檔案選擇器並以占位訊息送出（上傳 API 待接）
- 對話框/表單骨架：
  - Creator
    - Open: Accept（雙重確認 → 切 `in_progress`，保留舊清理其他聊天室動作）/ Block（骨架）
    - In Progress: Pay（含 Reviews 視窗：Service/Attitude/Experience 三個 5 顆星 + 100 字 comment；雙重支付碼輸入）/ Report（BottomSheet 表單骨架）
    - Pending Confirmation: Confirm / Disagree / Report（皆為骨架）
    - Dispute: Report（骨架）
    - Completed: Paid（時間戳視窗骨架）/ Reviews（可唯讀或可填寫骨架）/ Block（骨架）
  - Participant
    - Open: Report（骨架）
    - In Progress: Completed（雙重確認 → 切 `pending_confirmation_tasker`）/ Report（骨架）
    - Pending Confirmation: Report（骨架）
    - Completed/Rejected/Closed/Canceled: Report/Block（骨架）
- 其他相關 UI（已完成）
  - 已讀狀態：傳送中（時鐘）/ 已傳送（單勾）/ 已讀（雙勾）
  - 未讀提示浮條：不在底部時顯示半透明提示，點擊滾到底部
  - 對手頭像 fallback：`room.user.avatar_url → participant_avatar → avatar`

### 已完成（第二步：DB/API 串接 - MVP Skeleton）
- Report API：`backend/api/chat/report.php`（描述需≥10字）＋ 前端 `_openReportSheet()` 串接 ✅
- Pay 流程（MVP）：`backend/api/tasks/pay_and_review.php`（雙重支付碼，狀態切 Completed）＋ 前端 `_openPayAndReview()` ✅
- Reviews API：`backend/api/tasks/reviews_get.php` / `reviews_submit.php` ＋ 前端 `_openReviewDialog()` 先查詢再唯讀/預填 ✅
- Confirm（MVP）：`backend/api/tasks/confirm_completion.php`（先切狀態，後續補點數異動）✅
- Disagree（限制）：`backend/api/tasks/disagree_completion.php`（每任務最多 2 次）✅
- Block API：`backend/api/chat/block_user.php` ＋ 前端 Action 串接 ✅
  - 新增資料表：`user_blocks`（雙向封鎖）與端點相容自動建立 ✅
- 後端保護：`backend/api/chat/send_message.php` 禁止 Completed/Closed/Canceled/Rejected 狀態發送 ✅
- 附件上傳（MVP）：`backend/api/chat/upload_attachment.php` ＋ 前端 `ChatService.uploadAttachment()`、`_pickAndSendPhoto()` ✅

### 已完成（UI/UX 行為與主題整合）
- Action Bar 與輸入區域配色統一至 AppBar 主題（背景/前景/文字/icon）✅
- IconButton 與 TextField 的 hover/pressed/focus 狀態色以局部 Theme 覆寫，符合主題色階 ✅
- plus/photo icon 調整至輸入框左側，輸入列垂直置中、hint 左側 padding ✅
- 狀態 Bar 進入頁面自動顯示 3 秒後下滑消失（覆蓋於 Action Bar 上方）✅
- Divider 與 Action Bar 之間的空間改為 Action Bar 的 paddingTop，結構更一致 ✅

### 待辦（第二步：DB/API 進一步完善）
- Pay/Confirm：點數轉移、交易紀錄寫入、權限驗證與安全檢查
- Report：圖片上傳（evidence）與管理端審核流
- Block：黑名單策略（搜尋/投遞限制）→ `/tasks/list` 已過濾封鎖的任務發布者（不可見/不可應徵）；已應徵與既有聊天室保留 ✅
- 上傳圖片 API（chat attachments），訊息內顯示圖片縮圖

### 技術註記
- 行為映射集中於 `lib/chat/pages/chat_detail_page.dart` 的 `_buildActionButtonsByStatus()` 與彈窗 helper（`_openReportSheet` / `_openPayAndReview` / `_openReviewDialog` / `_showPaidInfo`）
- 後端串接完成後，將把骨架中的 TODO 逐一替換為 API 呼叫
- **View Resume 強化**: 以 `cover_letter` 作為自我推薦，`answers_json` 以「問題原文」為鍵；支援字串/物件雙格式解析
- **/task/apply 傳輸格式調整**: 前端改傳 `answers: {questionText: answer}`；後端 `apply.php` 僅存 q1..q3 相容回退
- **資料庫同步/清理**:
  - 將舊 `answers_json(q1/q2/q3/introduction)` 轉換為「問題原文」鍵
  - `introduction → cover_letter`（僅 cover 為空時）
  - 為開放中任務自動補 3 題自訂問題
- **聊天室參與者一致化**: 批次將 `chat_rooms.participant_id` 對齊最新 `task_applications.user_id`
- **假資料產生器**: 以新格式批量產生 `task_applications` 假資料

## 🚀 今日任務 (Day 2 - 8/9)
- **21 (Socket 核心)**
  - 建立 Node.js Socket.IO Gateway（auth/rooms/events）
  - 事件：auth/join_room/leave_room/send_message/read_room/typing
  - 推送：unread_total、unread_room
- **26（未讀 MVP）**
  - 後端 `unread_snapshot.php`（冷啟/重連一次性）
  - 前端 Navbar 徽章 + 進房清零
- **20（列表與面板收斂）**
  - Posted/My Works 用真實 API（`applications/list_by_user.php` + `acceptor_id` 規則）
  - 任務資訊 Bottom Sheet 定稿
- **27（部分）**
  - `acceptor_id` 型態與 FK 已處理；清理殘留程式的舊欄位依賴

## 📋 任務分類

### ✅ 已完成 (24個)
- 1-10: 核心功能完善
- 15-18: 基礎功能修復
- 19: 任務狀態設計文件
- 20a: 聊天列表載入修復 (2025/8/11)
- 20b: FutureBuilder 優化 (2025/8/11)
- 21: Socket.IO 整合 (2025/8/11) - 完成即時聊天基礎架構
- 26a: 聊天訊息持久化 (2025/8/11) - 訊息保存到資料庫
- 26b: 聊天室創建優化 (2025/8/11) - 任務應徵後自動創建聊天室

### 🔄 進行中 (2個)
- 26（未讀 UI 整合）
- 22（用戶權限系統）

### 📋 待執行 (41個)

#### 🗓️ Day 1 - 聊天室功能 ✅ 完成
- ~~20: 聊天室列表優化~~ ✅ 已完成 (2025/8/11)
- ~~21: Socket.IO 整合~~ ✅ 已完成 (2025/8/11) - 完成即時聊天架構
- ~~26a: 聊天訊息持久化~~ ✅ 已完成 (2025/8/11) - 訊息保存到資料庫
- 26b: 未讀通知系統 - 基礎架構已完成，待前端 UI 整合

#### 🗓️ Day 2 - 用戶權限 (3個)
- 22: 用戶權限系統
- 27: 資料庫結構優化
- 28: API 端點完善

#### 🗓️ Day 3 - 第三方登入 (4個)
- 52: 資料庫結構擴展
- 53: Google 登入
- 54: Facebook 登入
- 55: Apple ID 登入

#### 🗓️ Day 4 - 個人資料 (5個)
- 23: 個人資料頁面
- 24: 安全設定頁面
- 25: 任務歷史頁面
- 40: 預設頭像功能
- 41: 語言預設

#### 🗓️ Day 5 - 錢包系統 (7個)
- 30: 錢包主題配色
- 31: 官方帳戶資料表
- 32: 點數系統完善
- 33: 優惠券系統
- 34: 儲值功能
- 35: 點數歷史紀錄
- 39: 點數驗證

#### 🗓️ Day 6 - 客服支援 (4個)
- 36: 客服聊天室
- 37: FAQ 系統
- 38: 問題追蹤
- 42: 評分系統

#### 🗓️ Day 7 - 部署整合 (6個)
- 47: cPanel 部署準備
- 48: 資料庫遷移
- 49: 圖片上傳優化
- 50: 部署腳本
- 51: SSL 配置
- 29: UI/UX 優化

## 🎯 優先級策略

### 🔥 第一優先級 (必須完成)
1. 聊天室功能 (v3.3.0)
2. 用戶權限系統 (v3.3.1)
3. 個人資料功能 (v3.3.2)
4. 錢包系統 (v3.3.3)
5. 客服支援 (v3.3.4)

### 🔄 第二優先級 (可延後)
1. 第三方登入 (v3.4.1)
2. cPanel 部署 (v3.4.2)
3. 高級優化 (v3.4.3)

## ⚡ AI 開發指南

### 提示詞模板
```
**任務**: [編號] - [名稱]
**目標**: [具體目標]
**檔案**: [檔案路徑]
**要求**: [具體要求]
**參考**: [相關代碼]
```

### 效率技巧
- 模組化開發
- 代碼重用
- 快速迭代
- 上下文管理

### 模型切換快參（GPT‑5 vs fast）
- 預設 fast；以下情境切 GPT‑5：
  - 架構/跨模組/長上下文
  - 路由/狀態/權限/認證
  - 效能/競態/疑難除錯
- fast 適用：UI 微調、CRUD、樣板、測試/文件、重命名。
- 專案對應：GPT‑5 → `lib/router/app_router.dart`、`lib/auth/services/*`、`lib/chat/pages/*`；其餘日常 → fast。
- 詳細指引：見 `docs/CURSOR_TODO_OPTIMIZED.md` 的「AI 開發策略 > 模型切換指引」。

## 🔐 第三方登入申請
- **Google OAuth**: https://console.cloud.google.com/
- **Facebook Login**: https://developers.facebook.com/
- **Apple Sign-In**: https://developer.apple.com/

## 📞 支援資源
- **Flutter**: https://docs.flutter.dev/
- **PHP**: https://www.php.net/manual/
- **MySQL**: https://dev.mysql.com/doc/

---

**詳細文檔**: [CURSOR_TODO.md](./CURSOR_TODO.md) | [優化版](./CURSOR_TODO_OPTIMIZED.md) 