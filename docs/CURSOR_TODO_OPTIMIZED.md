# Here4Help MVP - 優化版 TODO 清單

## 📊 專案概覽

**當前狀態**: 36.9% 完成 (24/65 任務) | **目標**: 10天內完成 100% (8/8-8/17) | **完成機率**: 90%

### 🎯 核心指標
- **Flutter App**: 24/49 (49.0%) ✅ 
- **後台管理**: 0/4 (0.0%) 📋
- **cPanel 部署**: 0/5 (0.0%) 📋
- **第三方登入**: 0/7 (0.0%) 📋
- **TestFlight 上架**: 0/3 (0.0%) 📋

---

## 📋 相關文件確認

### ✅ 已整合的重要文件
- [x] **任務狀態設計**: `docs/TASK_STATUS_DESIGN.md` - 任務狀態和聊天室設計規範
- [x] **十天完成計劃**: `docs/TEN_DAY_PLAN.md` - 詳細的每日執行計劃
- [x] **cPanel 部署指南**: `docs/CPANEL_DEPLOYMENT_GUIDE.md` - 完整的部署流程
- [x] **TestFlight 上架指南**: `docs/TESTFLIGHT_GUIDE.md` - iOS 上架流程
- [x] **Cursor 執行指令**: `docs/CURSOR_EXECUTE.md` - 具體的執行步驟
- [x] **原始 TODO**: `docs/CURSOR_TODO.md` - 完整的詳細版本
- [x] **快速索引**: `docs/TODO_INDEX.md` - 快速導航版本

### 🎯 文件使用建議
- **日常開發**: 使用此優化版 (CURSOR_TODO_OPTIMIZED.md)
- **詳細參考**: 使用原始版 (CURSOR_TODO.md)
- **快速查詢**: 使用索引版 (TODO_INDEX.md)
- **任務狀態**: 參考 TASK_STATUS_DESIGN.md
- **部署指南**: 參考 CPANEL_DEPLOYMENT_GUIDE.md
- **上架指南**: 參考 TESTFLIGHT_GUIDE.md

---

## 🚀 十天執行計劃 (8/8-8/17)

| 日期 | 重點任務 | 任務編號 | 難度 | 時間 | 完成度 |
|------|----------|----------|------|------|--------|
| **Day 1 (8/8)** | 聊天室功能 ✅ | 20,21,26 | ⭐⭐⭐ | 8-10h | ✅ 100% |
| **Day 2 (8/9)** | 用戶權限系統 | 22,27,28 | ⭐⭐⭐⭐ | 10-12h | 36.9% |
| **Day 3 (8/10)** | 第三方登入 | 52,53,54,55 | ⭐⭐⭐⭐ | 10-12h | 47.7% |
| **Day 4 (8/11)** | 個人資料安全 | 23,24,25,40,41 | ⭐⭐⭐ | 8-10h | 53.8% |
| **Day 5 (8/12)** | 錢包支付系統 | 30-35,39 | ⭐⭐⭐⭐ | 10-12h | 61.5% |
| **Day 6 (8/13)** | 客服支援 | 36,37,38,42 | ⭐⭐⭐ | 8-10h | 67.7% |
| **Day 7 (8/14)** | 後台管理系統 | 43,44,45,46 | ⭐⭐⭐⭐ | 10-12h | 73.8% |
| **Day 8 (8/15)** | cPanel 部署 | 47-51 | ⭐⭐⭐⭐ | 10-12h | 80.0% |
| **Day 9 (8/16)** | TestFlight 上架 | 58-60 | ⭐⭐⭐⭐ | 10-12h | 87.7% |
| **Day 10 (8/17)** | 最終整合測試 | 61-65 | ⭐⭐⭐ | 8-10h | 100.0% |

---

## 🎯 MVP 優先級策略

### 🔥 第一優先級 (必須完成)
1. **聊天室功能** (v3.3.0) - 核心通訊
2. **用戶權限系統** (v3.3.1) - 基礎安全
3. **個人資料功能** (v3.3.2) - 用戶管理
4. **錢包系統** (v3.3.3) - 核心商業
5. **客服支援** (v3.3.4) - 用戶支援
6. **後台管理** (v3.3.5) - 管理功能
7. **cPanel 部署** (v3.3.6) - 生產環境
8. **TestFlight 上架** (v3.3.7) - iOS 發布

### 🔄 第二優先級 (可延後)
1. **第三方登入** (v3.4.1) - 用戶體驗優化
2. **高級優化** (v3.4.2) - 效能和體驗優化

---

## ⚡ AI 開發策略

### 🤖 Cursor AI 提示詞模板
```
**任務**: [任務編號] - [任務名稱]
**目標**: [具體目標]
**檔案**: [相關檔案路徑]
**要求**: 
1. [要求1]
2. [要求2]
3. [要求3]
**參考**: [相關代碼或文檔]
```

### 🎯 效率技巧
- **模組化開發**: 複雜任務分解為小模組
- **代碼重用**: 充分利用現有組件
- **快速迭代**: 邊開發邊測試
- **上下文管理**: 保持對話連續性
- **並行開發**: 前端和後端同時進行

### 🤖 模型切換指引（GPT‑5 vs fast）
- **預設**: 使用 fast（約 80% 任務）；遇到複雜/高風險再切 GPT‑5。
- **何時用 GPT‑5（手動切換）**：
  - 架構設計與大型重構（跨模組/跨檔案）
  - 導航/狀態/權限/認證流程梳理
  - 資料一致性、效能瓶頸、競態條件、棘手除錯
  - 長上下文任務（> 1-2K 行、跨多檔）
- **何時用 fast**：
  - UI 微調、樣式/排版、樣板程式、CRUD、小型重構
  - 撰寫單元測試/文件、重命名、格式化
- **Auto 模式**：單請求單模型，可能自動升降級；關鍵任務仍建議手動指定模型。
- **專案對應建議**：
  - GPT‑5：`lib/router/app_router.dart`、`lib/auth/services/*`、`lib/chat/pages/*`、跨模組流程
  - fast：`lib/task/pages/*` UI、`backend/api/*` 簡單端點、`lib/constants/*`、`lib/widgets/*`
- **實務快判**：需要跨檔推理/長上下文/高風險 → 用 GPT‑5；否則用 fast。
- **在 Cursor**：Inline/Composer 預設 fast；Chat 視需求切 GPT‑5。看到模型明顯不足時立即切換。

---

## 🔐 第三方登入申請指南

### 📋 申請清單
- [ ] **Google OAuth**: https://console.cloud.google.com/ | 專案: Here4Help
- [ ] **Facebook Login**: https://developers.facebook.com/ | 應用: Here4Help  
- [ ] **Apple Sign-In**: https://developer.apple.com/ | App ID: com.example.here4help

### 🚨 應急方案
- **本地模擬**: 先實現模擬登入流程
- **備用登入**: 郵箱密碼 + 手機號碼登入
- **訪客模式**: 允許部分功能使用

---

## 🚀 部署和上架計劃

### 📊 cPanel 部署計劃
- **Day 8 (8/15)**: 後端部署到 cPanel
- **Day 9 (8/16)**: 資料庫遷移和配置
- **Day 10 (8/17)**: 最終測試和優化

### 📱 TestFlight 上架計劃
- **Day 9 (8/16)**: iOS 應用打包和上傳
- **Day 10 (8/17)**: TestFlight 審核和發布

### 🔗 整合測試計劃
- **Day 10 (8/17)**: Flutter App 與 cPanel 後端整合測試

---

## 📋 任務清單 (65個任務)

### ✅ 已完成任務 (19個)
- [x] 1-10: 核心功能完善
- [x] 15-18: 基礎功能修復
- [x] 19: 任務狀態設計文件

### 🔄 進行中任務 (0個)
- 無

### 📋 待執行任務 (46個)

#### 🗓️ Day 1 - 聊天室功能 (v3.3.0)
**20. [ ] 聊天室列表頁面優化**
- 檔案: `lib/chat/pages/chat_list_page.dart`, `lib/task/pages/task_list_page.dart`
- 操作: 
  - Chat 列表懸浮視窗（Glassmorphism Bottom Sheet）、互斥滑動（已完成）
  - 狀態下拉改 `task_statuses`、Tab 切換重置（已完成）
  - My Works 規則與 `applications/list_by_user.php` 串接（已完成）
  - /task：Apply 按鈕禁用規則、Poster (You)、顯示所有任務（已完成）
  - /task：新篩選列（我的任務、已應徵、更新日期排序、重設 + 三下拉 All、語言來源 `languages`）（已完成）
- 狀態: 部分完成（8/9 收斂：未讀、Posted/My Works 真實資料、資訊面板最終版）

**21. [✅] 聊天室詳情頁面 Socket.IO 整合 + Action Bar API Skeleton** - 已完成 (2025/8/11)
- 檔案: `lib/chat/pages/chat_detail_page.dart`, `lib/chat/services/socket_service.dart`
- 操作: 整合 Socket.IO, 即時訊息, 訊息狀態, 打字指示器；Action Bar 串接 Report/Pay/Reviews/Confirm/Disagree/Block（MVP 骨架）；附件上傳（MVP）；主題化的 Action Bar/Input（hover/pressed/focus 狀態色）
- 狀態: ✅ 已完成
- 成果: 完成即時聊天基礎架構，支援即時訊息接收與發送；完成 Action Bar API 骨架，前後端基礎串接

**26. [🔄] 未讀訊息通知系統** - 部分完成 (2025/8/11)
- 檔案: `lib/services/notification_service.dart`, `lib/chat/services/socket_service.dart`
- 操作: 全局通知服務, bottom navbar 標記
- 狀態: 🔄 基礎架構已完成，待前端 UI 整合
- 成果: Socket.IO 未讀計數功能已實現，需要在聊天列表和導航欄顯示徽章

#### 🗓️ Day 2 - 8/9 Socket 核心實作（取代原 Day 2）
**A. Realtime Gateway（Node.js/Socket.IO）**
- 專案骨架 `backend/realtime/socket-server/`（Express + socket.io）
- 事件：auth/join_room/leave_room/send_message/read_room/typing
- DB 落庫：`chat_messages`（支援 kind/meta），房間：`room:<chat_room_id>`

**B. Flutter 串接 Socket**
- 套件 `socket_io_client`，登入後連線、加入房、收/送文字訊息
- Navbar 推播 `unread_total`，/chat 列表房間徽章

**C. HTTP 備援（冷啟/重連）**
- `chat/rooms/open_or_get.php`、`chat/messages/list.php`（首次載入）
- `unread_snapshot.php`（冷啟未讀快照）

**D. 列表與面板收斂**
- Posted/My Works 用真實 API（`applications/list_by_user.php` + `acceptor_id` 規則）
- 任務資訊 Bottom Sheet 交互與欄位定稿

#### 🗓️ Day 3 - 第三方登入系統 (v3.3.1)
**52. [ ] 第三方登入資料庫結構擴展**
- 檔案: `backend/database/migrations/add_oauth_fields.sql` (新增)
- 操作: 擴展 users 表, 創建 oauth_tokens 表, 實現遷移
- 狀態: 待執行

**53. [ ] Google 登入整合**
- 檔案: `lib/auth/services/google_auth_service.dart`
- 操作: 整合 google_sign_in 套件, 實現登入流程, 用戶資料映射
- 狀態: 待執行

**54. [ ] Facebook 登入整合**
- 檔案: `lib/auth/services/facebook_auth_service.dart` (新增)
- 操作: 整合 flutter_facebook_auth 套件, 實現登入流程
- 狀態: 待執行

**55. [ ] Apple ID 登入整合**
- 檔案: `lib/auth/services/apple_auth_service.dart` (新增)
- 操作: 整合 sign_in_with_apple 套件, 實現登入流程
- 狀態: 待執行

#### 🗓️ Day 4 - 個人資料和安全功能 (v3.3.2)
**23. [ ] 個人資料頁面功能完善**
- 檔案: `lib/account/pages/profile_page.dart`
- 操作: 個人資料修改, 頭像上傳, 圖片裁剪壓縮
- 狀態: 待執行

**24. [ ] 安全設定頁面功能完善**
- 檔案: `lib/account/pages/security_page.dart`
- 操作: 密碼修改, 帳號停權, 帳號刪除
- 狀態: 待執行

**25. [ ] 任務歷史頁面完善**
- 檔案: `lib/account/pages/task_history_page.dart`
- 操作: Posted/Accepted tabs, 任務歷史列表, 評分評論
- 狀態: 待執行

**40. [ ] 預設頭像功能實現**
- 檔案: `lib/utils/avatar_helper.dart` (新增)
- 操作: 預設頭像生成, 名稱首字母, 背景顏色隨機
- 狀態: 待執行

**41. [ ] 任務創建語言預設**
- 檔案: `lib/task/pages/task_create_page.dart`
- 操作: 讀取用戶主要語言, 預設填入, 語言選擇邏輯
- 狀態: 待執行

#### 🗓️ Day 5 - 錢包和支付系統 (v3.3.3)
**30. [ ] 錢包頁面主題配色優化**
- 檔案: `lib/account/pages/wallet_page.dart`
- 操作: 替換靜態顏色為主題配色, 深色模式支援
- 狀態: 待執行

**31. [ ] 官方帳戶資料表建立**
- 檔案: `backend/database/official_accounts.sql` (新增)
- 操作: 創建 official_accounts 表, 實現管理 API
- 狀態: 待執行

**32. [ ] 錢包點數系統完善**
- 檔案: `lib/account/pages/wallet_page.dart`
- 操作: 兩行點數顯示, 點數數字格式, 收支歷史紀錄
- 狀態: 待執行

**33. [ ] 優惠券系統實現**
- 檔案: `backend/database/coupons.sql` (新增)
- 操作: 創建 coupons 表, 實現優惠券列表和領取功能
- 狀態: 待執行

**34. [ ] 儲值功能實現**
- 檔案: `lib/account/pages/add_points_page.dart` (新增)
- 操作: Amount 驗證, 末五碼驗證, 儲值確認對話框
- 狀態: 待執行

**35. [ ] 點數收支歷史紀錄**
- 檔案: `backend/database/point_transactions.sql` (新增)
- 操作: 創建 point_transactions 表, 實現歷史紀錄頁面
- 狀態: 待執行

**39. [ ] 任務創建點數驗證**
- 檔案: `lib/task/pages/task_create_page.dart`
- 操作: 點數餘額檢查, 點數不足提醒, 點數扣除邏輯
- 狀態: 待執行

#### 🗓️ Day 6 - 客服支援系統 (v3.3.4)
**36. [ ] 客服聊天室功能**
- 檔案: `backend/database/support_chats.sql` (新增)
- 操作: 創建 support_chats 表, Socket.IO 客服聊天, 圖片上傳
- 狀態: 待執行

**37. [ ] FAQ 系統實現**
- 檔案: `backend/database/faqs.sql` (新增)
- 操作: 創建 faqs 表, 實現 FAQ 列表 API, 搜尋功能
- 狀態: 待執行

**38. [ ] 問題追蹤系統**
- 檔案: `backend/database/support_issues.sql` (新增)
- 操作: 創建 support_issues 表, 問題提交, 狀態更新
- 狀態: 待執行

**42. [ ] 評分系統實現**
- 檔案: `backend/database/task_ratings.sql` (新增)
- 操作: 創建 task_ratings 表, 五星評分組件, 評分提交
- 狀態: 待執行

#### 🗓️ Day 7 - 後台管理系統 (v3.3.5)
**43. [ ] 學生證驗證管理系統**
- 檔案: `backend/admin/student_verification.php` (新增)
- 操作: 學生證驗證列表, 審核功能, 狀態更新
- 狀態: 待執行

**44. [ ] 匯款審核系統**
- 檔案: `backend/admin/payment_review.php` (新增)
- 操作: 匯款申請列表, 審核功能, 狀態更新
- 狀態: 待執行

**45. [ ] 匯款帳戶管理系統**
- 檔案: `backend/admin/payment_accounts.php` (新增)
- 操作: 官方帳戶列表, 新增/編輯/刪除功能
- 狀態: 待執行

**46. [ ] 後台UI/UX優化**
- 檔案: `backend/admin/` (更新所有頁面)
- 操作: 統一設計風格, 響應式設計, 用戶體驗優化
- 狀態: 待執行

#### 🗓️ Day 8 - cPanel 部署 (v3.3.6)
**47. [ ] cPanel 後端部署準備**
- 檔案: `backend/config/production.php` (新增)
- 操作: 生產環境配置, 資料庫連線, .htaccess 配置
- 狀態: 待執行

**48. [ ] 資料庫遷移和備份策略**
- 檔案: `backend/scripts/backup.php` (新增)
- 操作: 資料庫遷移腳本, 備份還原機制, 版本控制
- 狀態: 待執行

**49. [ ] 圖片上傳機制優化**
- 檔案: `backend/utils/image-processor.php` (新增)
- 操作: 圖片壓縮優化, 快取機制, 縮圖生成
- 狀態: 待執行

**50. [ ] cPanel 部署腳本**
- 檔案: `deploy/cpanel-deploy.sh` (新增)
- 操作: 自動化部署腳本, 資料庫同步, 回滾機制
- 狀態: 待執行

**51. [ ] SSL 和安全性配置**
- 檔案: `backend/config/security.php` (新增)
- 操作: SSL 憑證配置, HTTPS 重導向, 安全性標頭
- 狀態: 待執行

#### 🗓️ Day 9 - TestFlight 上架 (v3.3.7)
**58. [ ] iOS 應用打包**
- 檔案: `deploy/build_ios.sh` (新增)
- 操作: 使用 Flutter 命令打包 iOS 應用
- 狀態: 待執行

**59. [ ] TestFlight 上傳**
- 檔案: `deploy/upload_to_testflight.sh` (新增)
- 操作: 使用 `xcrun` 命令上傳到 TestFlight
- 狀態: 待執行

**60. [ ] TestFlight 審核**
- 檔案: `deploy/submit_to_app_store_connect.sh` (新增)
- 操作: 使用 `xcrun` 命令提交到 App Store Connect
- 狀態: 待執行

#### 🗓️ Day 10 - 最終整合測試 (v3.4.0)
**61. [ ] Flutter App 與 cPanel 整合測試**
- 檔案: `lib/main.dart`
- 操作: 啟動 App, 測試所有功能, 確保與後端通訊正常
- 狀態: 待執行

**62. [ ] 最終整合測試**
- 檔案: `lib/main.dart`
- 操作: 所有功能整合測試, 包括登入、聊天、支付、客服等
- 狀態: 待執行

**63. [ ] 性能優化**
- 檔案: `lib/main.dart`
- 操作: 測試 App 啟動時間、響應速度、內存使用等
- 狀態: 待執行

**64. [ ] 錯誤追蹤和日誌**
- 檔案: `lib/main.dart`
- 操作: 收集所有錯誤日誌, 分析性能問題
- 狀態: 待執行

**65. [ ] 最終版本發布**
- 檔案: `lib/main.dart`
- 操作: 打包最終版本, 準備發布
- 狀態: 待執行

---

## 📈 版本完成度追蹤

| 版本 | 完成度 | 主要功能 | 狀態 |
|------|--------|----------|------|
| v3.2.5 | 29.2% | Salary → Reward Point | ✅ |
| v3.2.6 | 30.8% | 語言名稱顯示優化 | ✅ |
| v3.2.7 | 32.3% | TaskCreatePage 完善 | ✅ |
| v3.2.8 | 33.8% | 用戶頭貼修復 | ✅ |
| v3.2.9 | 35.4% | 任務狀態設計 | ✅ |
| v3.3.0 | 38.5% | 聊天室功能 | 🔄 |
| v3.3.1 | 44.6% | 用戶權限+第三方登入 | 📋 |
| v3.3.2 | 47.7% | 個人資料+安全 | 📋 |
| v3.3.3 | 55.4% | 錢包+支付系統 | 📋 |
| v3.3.4 | 61.5% | 客服支援系統 | 📋 |
| v3.3.5 | 69.2% | cPanel 部署 | 📋 |
| v3.3.6 | 73.8% | 後台管理系統 | 📋 |
| v3.3.7 | 80.0% | cPanel 部署+TestFlight 上架 | 📋 |
| v3.4.0 | 100.0% | 所有功能整合 | 📋 |

---

## 🚨 風險管理

### 高風險任務
1. **第三方登入** (Day 3) → 應急: 本地模擬
2. **Socket.IO 整合** (Day 1) → 應急: 輪詢機制
3. **cPanel 部署** (Day 8) → 應急: 詳細文檔
4. **TestFlight 上架** (Day 9) → 應急: 審核流程

### 並行開發策略
- 前端和後端並行開發
- 模組化獨立開發
- 測試驅動開發

---

## 📞 支援資源

### 技術文檔
- **Flutter**: https://docs.flutter.dev/
- **Dart**: https://dart.dev/guides
- **PHP**: https://www.php.net/manual/
- **MySQL**: https://dev.mysql.com/doc/

### 第三方服務
- **Google OAuth**: https://developers.google.com/identity
- **Facebook Login**: https://developers.facebook.com/docs/facebook-login
- **Apple Sign-In**: https://developer.apple.com/sign-in-with-apple/

### 部署資源
- **cPanel**: https://docs.cpanel.net/
- **SSL**: Let's Encrypt 免費憑證
- **CDN**: Cloudflare 免費 CDN

---

**最後更新**: 2025年8月8日 | **版本**: v2.0 | **狀態**: 優化完成，準備執行 