## 新增里程碑與執行順序（同步 plan.json）

### 管理員後台（Laravel + Vue）
- 路由分離：/api/admin/*（Sanctum + RBAC）
- 資料表：admins/admin_roles/admin_role_permissions/admin_activity_logs/admin_login_logs
- 頁面樹：/login, /users(list/review/edit), /tasks(list/logs), /services(list/chat/events list/view/stats), /points(list/manual-add), /admins(list/create/reset-password)
- 指令：
```bash
composer create-project laravel/laravel admin
cd admin && composer require laravel/sanctum
php artisan make:controller Admin/AuthController
php artisan make:middleware AdminMiddleware
php artisan migrate
```
- 驗收：可登入；無權限 403；稽核紀錄寫入

### 帳號安全與保護（停用/啟用/風險檢查）
- API：GET /account/risky-actions-check, POST /account/deactivate, POST /account/reactivate
- 前端：/account/security 流程提示與禁用動作
- 驗收：有進行中/發布中任務時先提示；自停用後可再啟用（非被管理員停權）

### 全域權限與路由守衛
- 前端：lib/router/guards/permission_guard.dart，路由級與元件級
- 驗收：不同 permission/status 下導向與禁用一致

### 歷史任務與未評價快捷
- API：GET /tasks/history?role=poster|acceptor
- 前端：history_page + review_dialog
- 驗收：未評價項目可快捷評分

### 第三方首次登入導引
- 回傳 isNewUser 與 session_key（沿用 temp token）；router 導向 /signup 預填

### 用戶帳號設定模組
- 改密碼、重設信、重設密碼、停權、刪帳、恢復
- 驗收：完整流程可操作，安全性校驗完整

### /chat POST 分頁滑動工具列
- Slidable/Dismissible + 可擴充動作列（Read/Delete/Reject...）
- 依任務狀態條件顯示

### 1v1 聊天室 Action Bar（狀態×角色矩陣）
- 主要動作：confirm, cancel, complete, dispute...
- 驗收：矩陣覆蓋主要任務狀態，動作正確觸發

### 任務自動完成與申訴流程
- 排程：pending confirmation > 7 天 → completed（寫 task_logs）
- Dispute：Action Bar 觸發 → 轉 dispute 並停止倒數；後台審核（含圖片）

### 帳號安全加固（M-SECURITY-HARDENING）
- 強制 HTTPS、JWT 簽章旋轉、Laravel CSRF 中介層
- 驗收：敏感 API 請求必須帶 Token；無效 Token → 401；舊簽章拒絕

### API 合約文件化（M-API-CONTRACTS）
- 使用 OpenAPI/Swagger，後端自動生成文件
- 驗收：前後端可依合約 Mock 測試；變更需版本化

### 監控與觀測性（M-OBSERVABILITY）
- Laravel Telescope + Sentry；Flutter Crashlytics
- 驗收：錯誤能追蹤；請求耗時可見；Flutter 端崩潰有回報

### 資料治理（M-DATA-GOVERNANCE）
- GDPR/刪除帳號 → 匿名化；稽核 log 保留
- 驗收：刪帳後無個資；查詢保留稽核紀錄

### 媒體處理（M-MEDIA-PIPELINE）
- 圖片壓縮、格式化；Laravel Storage + Cloud（S3/Cloudflare R2）
- 驗收：上傳圖片有壓縮；後端可安全訪問

### 通知策略（M-NOTIFICATION-POLICY）
- 任務/客服事件 → FCM + Email；靜音/Pin 支援
- 驗收：通知可配置；靜音時不推送


### 離線模式與斷線恢復（M-OFFLINE-RESILIENCE）
- Flutter local DB（sqflite）；背景重試
- 驗收：無網路可瀏覽快取；恢復後自動同步

### 無障礙與空/錯誤狀態（M-A11Y & EMPTY-ERROR-STATES）
- Flutter a11y labels、空清單頁 UI、錯誤提示頁
- 驗收：螢幕閱讀器可讀；空狀態顯示正確；錯誤提示一致
