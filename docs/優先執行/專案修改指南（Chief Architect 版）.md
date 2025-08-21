# Here4Help 專案修改指南（Chief Architect 版）

> 本指南基於高階專案分析指令文件格式，提供可直接執行的專案修改方案
> 目標：第三方登入 OAuth token 化流程、管理員後台（Laravel + Vue）、客服事件紀錄模組、任務收藏與檢舉功能

---

## 📋 專案背景

- **產品**: Here4Help（Flutter App）
- **後端**: 原生 PHP + MySQL，規劃管理員後台使用 Laravel + Vue
- **功能域**: 註冊/登入（Email + Google/Apple/Facebook）、任務與應徵、聊天室（WebSocket）、客服、會員點數、權限/等級
- **部署**: CPanel / TestFlight 內測
- **近期重點**: 第三方登入 OAuth token 化、管理員後台、客服事件紀錄、任務收藏與檢舉

---

## 🎯 架構決策（ADR）

### 第三方登入 OAuth Token 化流程
- **新用戶**: OAuth 成功 → 回調寫入 `oauth_temp_users` → 產一次性 token（預設 1h 有效）→ 重導 `/signup?token=...` → `/signup` 以 token 呼叫新 API 預填 → 註冊成功後產生 `users` + `user_identities` → JWT → `/signup/student-id` 或 `/home`
- **既有用戶**: 回調命中 `user_identities`（或可精準映射 `users`）→ 直接簽發 JWT → `/home`
- **安全性**: `/signup` 僅帶 token，不在 URL 帶個資；token 一次性；過期與重複使用要有清楚錯誤
- **環境一致**: `FRONTEND_URL` 與 allowlist 僅 `http://localhost:3000`；Google Console Redirect URI 完全一致

### 管理員後台架構
- **技術棧**: Laravel + Vue.js
- **路由分離**: `/api/admin/*` 與前台 `/api/*` 分離
- **認證**: Laravel Sanctum，與前台 JWT 分離
- **權限**: RBAC 系統，支援角色與權限管理

### 客服事件紀錄模組
- **限制**: 僅支援 `chat_rooms.type = support` 的聊天室
- **狀態流程**: open → in_progress → resolved → closed_by_customer
- **客戶評分**: 事件完成後可評分與評論
- **管理員統計**: 滿意度平均、處理時長、案件數統計

---

## 📊 環境配置

### 開發環境
- **Frontend**: `http://localhost:3000`
- **Socket**: `ws://localhost:3001`
- **MAMP Web**: `http://localhost:8888/here4help`
- **MAMP DB**: `localhost:8889`

### Google Console 設定
- **Authorized redirect URI**: `http://localhost:8888/here4help/backend/api/auth/google-callback.php`
- **Authorized JavaScript origins**:
  - `http://localhost:3000`
  - `http://localhost:8888`

---

## 🚀 里程碑與任務分解

### M-OAUTH-TEMP-FLOW 第三方登入 token 化
- **目標**: 實作完整的第三方登入 OAuth token 化流程
- **範圍**: Google、Facebook、Apple 登入
- **時程**: 5 個 PR，預計 2 週完成

### M-ADMIN-BACKEND 管理員後台
- **目標**: 建立 Laravel + Vue 管理員後台
- **範圍**: 用戶管理、任務管理、客服系統、點數管理
- **時程**: 4 個 PR，預計 3 週完成

### M-SUPPORT-EVENTS 客服事件紀錄
- **目標**: 實作客服事件紀錄與管理系統
- **範圍**: 事件建立、狀態管理、客戶評分、管理員統計
- **時程**: 3 個 PR，預計 2 週完成

### M-TASK-FEATURES 任務功能增強
- **目標**: 新增任務收藏與檢舉功能
- **範圍**: 收藏管理、檢舉系統、管理員審核
- **時程**: 2 個 PR，預計 1 週完成

---

## 📝 任務詳解

### T1-BE-CALLBACK-SAVE-TEMP（對應 TODO: callback-save-temp-and-token）
- **目標**: 重構 Google/Facebook/Apple 回調，寫入 oauth_temp_users 並簽發一次性 token
- **檔案**: `backend/api/auth/google-callback.php`（後續：`facebook-callback.php`、`apple-callback.php`）
- **工作**:
  - 命中新用戶 → 寫 `oauth_temp_users` + 產一次性 token → `302` 至 `${FRONTEND_URL}/signup?token=...`
  - 命中既有用戶 → 簽發 JWT → `302` 至 `${FRONTEND_URL}/home?provider=google`
  - 統一錯誤重導 `/auth/callback?success=false&provider=google&error=...`
- **指令**:
  ```bash
  php -l backend/api/auth/google-callback.php
  php backend/test_google_oauth_config.php
  tail -50 /Applications/MAMP/logs/php_error.log 2>/dev/null
  ```
- **驗收**: 新/舊用戶重導正確；錯誤重導一致
- **回滾**: 暫時切回舊分支（直接建 users/user_identities）或停用新分流

### T2-BE-API-FETCH-TEMP（對應 TODO: api-fetch-temp-user）
- **目標**: 新增 API：GET /auth/oauth-temp?token=... 供 /signup 預填；設定逾期/一次性使用
- **端點**: `GET /backend/api/auth/oauth-temp.php?token=...&peek=true`
- **工作**:
  - token 有效 → 返回 `{ provider, provider_user_id, name, email, avatar_url }`（`raw_data`節選）
  - token 無效/逾期 → `400/404` 與清楚訊息
- **檔案**: `backend/api/auth/oauth-temp.php`（新）
- **指令**:
  ```bash
  php -l backend/api/auth/oauth-temp.php
  curl -s 'http://localhost:8888/here4help/backend/api/auth/oauth-temp.php?token=TEST_TOKEN&peek=true'
  ```
- **驗收**: peek 可查看、未消費；若已被 T3 消費，token 失效

### T3-BE-REGISTER-CONSUME-TEMP（對應 TODO: api-register-consume-temp）
- **目標**: 改造註冊 API：消費 temp token 建立 users + user_identities，成功後刪除臨時資料
- **端點**: `POST /backend/api/auth/register-oauth.php`
- **工作**: 交易流程：消費 token → 建 `users` → 建 `user_identities` 綁定 → 刪除臨時 token → 簽發 JWT
- **檔案**: `backend/api/auth/register-oauth.php`
- **指令**:
  ```bash
  php -l backend/api/auth/register-oauth.php
  curl -s -X POST -H 'Content-Type: application/json' -d '{"token":"TEST_TOKEN","name":"Test User"}' http://localhost:8888/here4help/backend/api/auth/register-oauth.php
  ```
- **驗收**: 單 token 單次可用；成功回傳 `{ token, user }`

### T4-FE-SIGNUP-PREFILL（對應 TODO: fe-signup-prefill-by-token）
- **目標**: 前端 /signup 支援以 token 載入預填資料；UI 處理 token 過期/錯誤狀態
- **工作**: `/signup` 檢查 `token` → 呼叫 `GET /auth/oauth-temp` → 預填（name/email/avatar）
- **檔案**: `lib/auth/pages/signup_page.dart`、`lib/services/api/oauth_api.dart`（新）
- **指令**:
  ```bash
  flutter analyze
  flutter test --plain-name signup
  ```
- **驗收**: 預填 OK；過期/錯誤提示並引導返回登入

### T5-FE-OAUTH-WIRING（對應 TODO: fe-oauth-flow-wiring）
- **目標**: 前端第三方登入流程銜接：web OAuth → 後端回調 → 跳 /signup?token=...
- **工作**: Web OAuth → 回調 → 依 isNewUser 分流 → `/signup?token=...` 或 `/home`
- **檔案**: `lib/auth/services/third_party_auth_service.dart`、`lib/auth/pages/auth_callback_page.dart`、`lib/router/app_router.dart`
- **指令**:
  ```bash
  flutter analyze
  flutter test --plain-name oauth
  ```
- **驗收**: Google 完成；Facebook/Apple 後續

### T6-LAR-ADMIN-SETUP 管理員後台基礎架構
- **目標**: 建立 Laravel 管理員後台基礎架構
- **工作**:
  - 建立 Laravel 專案結構
  - 設定資料庫連線與認證
  - 建立基礎路由與控制器
- **檔案**: `admin/` 目錄結構、`admin/routes/api.php`、`admin/app/Http/Controllers/Admin/`
- **指令**:
  ```bash
  composer create-project laravel/laravel admin
  cd admin && composer require laravel/sanctum
  php artisan make:controller Admin/AuthController
  ```
- **驗收**: Laravel 專案可正常啟動，基礎路由可訪問

### T7-LAR-ADMIN-AUTH 管理員認證系統
- **目標**: 實作管理員登入與權限控制
- **工作**:
  - 建立管理員認證 API
  - 實作 RBAC 權限系統
  - 建立管理員中間件
- **檔案**: `admin/app/Http/Controllers/Admin/AuthController.php`、`admin/app/Http/Middleware/AdminMiddleware.php`
- **指令**:
  ```bash
  php artisan make:middleware AdminMiddleware
  php artisan route:list --path=admin
  ```
- **驗收**: 管理員可正常登入，權限控制生效

### T8-VUE-ADMIN-UI 管理員前端介面
- **目標**: 建立 Vue.js 管理員前端介面
- **工作**:
  - 建立 Vue 專案結構
  - 實作路由與狀態管理
  - 建立基礎 UI 組件
- **檔案**: `admin/admin-frontend/` 目錄結構
- **指令**:
  ```bash
  npm create vue@latest admin-frontend
  cd admin-frontend && npm install axios vue-router pinia
  ```
- **驗收**: Vue 專案可正常啟動，基礎路由可訪問

### T9-BE-SUPPORT-EVENTS 客服事件後端 API
- **目標**: 實作客服事件紀錄後端 API
- **工作**:
  - 建立 support_events 與 support_event_logs 資料表
  - 實作事件 CRUD API
  - 實作事件狀態管理
- **檔案**: `backend/api/support/events.php`、`backend/database/migrations/`
- **指令**:
  ```bash
  php -l backend/api/support/events.php
  curl -s 'http://localhost:8888/here4help/backend/api/support/events?chat_room_id=1'
  ```
- **驗收**: 事件可正常建立、查詢、更新

### T10-FE-SUPPORT-EVENTS 客服事件前端介面
- **目標**: 實作客服事件前端介面
- **工作**:
  - 建立事件列表頁面
  - 實作事件詳情頁面
  - 實作事件狀態更新
- **檔案**: `lib/pages/support/issues_status_page.dart`、`lib/widgets/support_event_card.dart`
- **指令**:
  ```bash
  flutter analyze
  flutter test --plain-name support_events
  ```
- **驗收**: 事件列表可正常顯示，狀態更新正常

### T11-BE-TASK-FEATURES 任務功能後端 API
- **目標**: 實作任務收藏與檢舉後端 API
- **工作**:
  - 建立 task_favorites 與 task_reports 資料表
  - 實作收藏管理 API
  - 實作檢舉系統 API
- **檔案**: `backend/api/tasks/favorites.php`、`backend/api/tasks/reports.php`
- **指令**:
  ```bash
  php -l backend/api/tasks/favorites.php
  curl -s 'http://localhost:8888/here4help/backend/api/tasks/favorites?user_id=1'
  ```
- **驗收**: 收藏與檢舉功能正常運作

### T12-FE-TASK-FEATURES 任務功能前端介面
- **目標**: 實作任務收藏與檢舉前端介面
- **工作**:
  - 在任務卡片新增收藏按鈕
  - 實作檢舉對話框
  - 實作收藏列表頁面
- **檔案**: `lib/widgets/task_card.dart`、`lib/pages/account/favorites_page.dart`
- **指令**:
  ```bash
  flutter analyze
  flutter test --plain-name task_features
  ```
- **驗收**: 收藏與檢舉 UI 正常運作

---

## 🗄️ 資料庫設計

### oauth_temp_users 表（已完成）
```sql
CREATE TABLE IF NOT EXISTS `oauth_temp_users` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `provider` VARCHAR(32) NOT NULL,
  `provider_user_id` VARCHAR(191) NOT NULL,
  `email` VARCHAR(255) NULL,
  `name` VARCHAR(255) NULL,
  `avatar_url` TEXT NULL,
  `raw_data` JSON NULL,
  `token` VARCHAR(64) NOT NULL,
  `expired_at` TIMESTAMP NOT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_token` (`token`),
  UNIQUE KEY `uq_provider_uid` (`provider`, `provider_user_id`),
  KEY `idx_expired_at` (`expired_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### support_events 表
```sql
CREATE TABLE IF NOT EXISTS `support_events` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `chat_room_id` BIGINT UNSIGNED NOT NULL,
  `title` VARCHAR(255) NOT NULL,
  `description` TEXT NOT NULL,
  `status` ENUM('open', 'in_progress', 'resolved', 'closed_by_customer') NOT NULL DEFAULT 'open',
  `created_by` BIGINT UNSIGNED NOT NULL,
  `closed_by` BIGINT UNSIGNED NULL,
  `rating` TINYINT NULL,
  `review` TEXT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `closed_at` TIMESTAMP NULL,
  PRIMARY KEY (`id`),
  KEY `idx_chat_room` (`chat_room_id`),
  KEY `idx_status` (`status`),
  KEY `idx_created_by` (`created_by`),
  CONSTRAINT `fk_support_events_chat_room` FOREIGN KEY (`chat_room_id`) REFERENCES `chat_rooms`(`id`),
  CONSTRAINT `fk_support_events_created_by` FOREIGN KEY (`created_by`) REFERENCES `users`(`id`),
  CONSTRAINT `fk_support_events_closed_by` FOREIGN KEY (`closed_by`) REFERENCES `users`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### task_favorites 表
```sql
CREATE TABLE IF NOT EXISTS `task_favorites` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `task_id` VARCHAR(36) NOT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_user_task` (`user_id`, `task_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_task_id` (`task_id`),
  CONSTRAINT `fk_task_favorites_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`),
  CONSTRAINT `fk_task_favorites_task` FOREIGN KEY (`task_id`) REFERENCES `tasks`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## 🧪 測試計畫

### 單元測試
- **OAuth 流程**: 測試 token 生成、驗證、消費流程
- **API 端點**: 測試所有新增 API 端點
- **前端組件**: 測試新增的 Flutter 組件
- **管理員後台**: 測試 Laravel 控制器與 Vue 組件

### 端到端測試
- **新用戶流程**: OAuth → 回調 → 註冊 → 完成
- **既有用戶流程**: OAuth → 回調 → 直接登入
- **客服事件**: 建立事件 → 狀態更新 → 客戶評分
- **任務功能**: 收藏任務 → 檢舉任務 → 管理員處理

### 測試指令
```bash
# 後端測試
php backend/test_google_oauth_config.php
php -l backend/api/auth/oauth-temp.php
curl -s 'http://localhost:8888/here4help/backend/api/auth/oauth-temp.php?token=TEST_TOKEN&peek=true'

# 前端測試
flutter analyze
flutter test --plain-name signup
flutter test --plain-name oauth

# 管理員後台測試
cd admin && php artisan test
cd admin-frontend && npm run test
```

---

## 📋 PR 切分建議

### PR1: OAuth Token 化基礎架構
- **範圍**: T1-BE-CALLBACK-SAVE-TEMP、T2-BE-API-FETCH-TEMP
- **檔案**: `backend/api/auth/google-callback.php`、`backend/api/auth/oauth-temp.php`
- **驗收**: 回調可正常處理新/舊用戶分流

### PR2: OAuth 註冊流程
- **範圍**: T3-BE-REGISTER-CONSUME-TEMP、T4-FE-SIGNUP-PREFILL
- **檔案**: `backend/api/auth/register-oauth.php`、`lib/auth/pages/signup_page.dart`
- **驗收**: 新用戶可完成 OAuth 註冊流程

### PR3: OAuth 流程整合
- **範圍**: T5-FE-OAUTH-WIRING、T7-ENV-ALLOWLIST
- **檔案**: `lib/auth/services/third_party_auth_service.dart`、`backend/config/.env`
- **驗收**: 完整 OAuth 流程可正常運作

### PR4: 管理員後台基礎
- **範圍**: T6-LAR-ADMIN-SETUP、T7-LAR-ADMIN-AUTH
- **檔案**: `admin/` 目錄結構
- **驗收**: 管理員後台可正常登入與訪問

### PR5: 管理員後台功能
- **範圍**: T8-VUE-ADMIN-UI、管理員功能實作
- **檔案**: `admin/admin-frontend/` 目錄結構
- **驗收**: 管理員功能可正常使用

### PR6: 客服事件系統
- **範圍**: T9-BE-SUPPORT-EVENTS、T10-FE-SUPPORT-EVENTS
- **檔案**: `backend/api/support/events.php`、`lib/pages/support/`
- **驗收**: 客服事件系統可正常運作

### PR7: 任務功能增強
- **範圍**: T11-BE-TASK-FEATURES、T12-FE-TASK-FEATURES
- **檔案**: `backend/api/tasks/favorites.php`、`lib/widgets/task_card.dart`
- **驗收**: 任務收藏與檢舉功能正常

---

## 🔄 回滾方案

### 資料庫回滾
```sql
-- 清空測試資料
DELETE FROM oauth_temp_users WHERE expired_at < NOW();
DELETE FROM support_events WHERE created_at < DATE_SUB(NOW(), INTERVAL 1 DAY);
DELETE FROM task_favorites WHERE created_at < DATE_SUB(NOW(), INTERVAL 1 DAY);

-- 回滾資料表（僅測試環境）
DROP TABLE IF EXISTS oauth_temp_users;
DROP TABLE IF EXISTS support_events;
DROP TABLE IF EXISTS support_event_logs;
DROP TABLE IF EXISTS task_favorites;
DROP TABLE IF EXISTS task_reports;
```

### 程式碼回滾
- **OAuth 流程**: 切回舊的回調分支
- **管理員後台**: 移除 `admin/` 目錄
- **前端功能**: 移除新增的組件與頁面

### 環境回滾
```bash
# 恢復環境配置
git checkout HEAD -- backend/config/.env
git checkout HEAD -- assets/app_env/development.json

# 清理快取
flutter clean
cd admin && php artisan cache:clear
```

---

## 📊 驗收清單

### OAuth Token 化流程
- ✅ 新用戶分流正確：OAuth → `/signup?token=...`
- ✅ 既有用戶分流正確：OAuth → `/home`
- ✅ Token 一次性使用：過期/重複消費 → 失敗
- ✅ 環境配置一致：Frontend 3000、Google Console Redirect 完全一致

### 管理員後台
- ✅ Laravel 專案可正常啟動
- ✅ 管理員認證系統正常運作
- ✅ Vue 前端介面可正常訪問
- ✅ RBAC 權限控制生效

### 客服事件系統
- ✅ 事件可正常建立與管理
- ✅ 狀態流程正常運作
- ✅ 客戶評分功能正常
- ✅ 管理員統計功能正常

### 任務功能增強
- ✅ 任務收藏功能正常
- ✅ 任務檢舉功能正常
- ✅ 管理員審核功能正常

---

## 🚀 執行順序

1. **環境準備**: 確認 MAMP、Flutter、Node.js 環境正常
2. **資料庫準備**: 執行資料表建立 SQL
3. **OAuth 流程**: 按 PR1 → PR2 → PR3 順序執行
4. **管理員後台**: 按 PR4 → PR5 順序執行
5. **功能模組**: 按 PR6 → PR7 順序執行
6. **測試驗收**: 執行完整測試計畫
7. **文件更新**: 更新變更記錄與文件

---

## 📞 聯絡與支援

- **技術問題**: 檢查 `docs/優先執行/ReadME_Here4Help專案＿變更記錄追蹤表.md`
- **環境問題**: 執行 `php backend/check_environment.php`
- **資料庫問題**: 執行 `php backend/check_database_structure.php`
- **前端問題**: 執行 `flutter doctor` 與 `flutter analyze`
