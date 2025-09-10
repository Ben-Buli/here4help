# 管理員後台版本推送檢查清單

## 📋 推送範圍
本次推送僅包含**管理員後台相關**的文件，排除測試文件、第三方登入配置、執行紀錄等敏感內容。

## ✅ 應該推送的文件

### Laravel 後端 (admin/)
```
admin/app/Http/Controllers/Admin/
├── DisputeController.php          ✅ 爭議處理控制器
├── SupportController.php          ✅ 客服支援控制器  
├── UserController.php             ✅ 用戶管理控制器
├── PaymentController.php          ✅ 支付管理控制器
├── TaskController.php             ✅ 任務管理控制器
└── DashboardController.php        ✅ 儀表板控制器

admin/routes/api.php               ✅ API 路由定義
admin/config/                      ✅ Laravel 配置文件
admin/database/migrations/         ✅ 資料庫遷移文件
admin/database/seeders/            ✅ 資料庫種子文件
```

### Vue.js 前端 (admin/frontend/)
```
admin/frontend/src/
├── components/                    ✅ Vue 組件
│   ├── AppLayout.vue             ✅ 主要布局
│   ├── wallet/                   ✅ 錢包相關組件
│   ├── DisputeChatRoomModal.vue  ✅ 爭議聊天室
│   ├── DisputeReviewDialog.vue   ✅ 爭議審核對話框
│   ├── UserReviewModal.vue       ✅ 用戶審核模態框
│   └── Icon.vue                  ✅ 圖標組件
├── views/                        ✅ 頁面視圖
│   ├── UsersView.vue             ✅ 用戶管理頁面
│   ├── TasksView.vue             ✅ 任務管理頁面
│   ├── TaskDisputesView.vue      ✅ 爭議管理頁面
│   ├── SupportChatListView.vue   ✅ 客服聊天列表
│   ├── IssuesView.vue            ✅ 問題管理頁面
│   └── UserTransactionsView.vue  ✅ 用戶交易記錄
├── services/                     ✅ API 服務
│   ├── api.ts                    ✅ API 定義
│   └── chat-permission-service.ts ✅ 聊天權限服務
├── config/                       ✅ 配置文件
│   ├── api.ts                    ✅ API 配置
│   ├── app.ts                    ✅ 應用配置
│   └── env.ts                    ✅ 環境配置
└── router/index.ts               ✅ 路由配置

admin/frontend/vite.config.ts     ✅ Vite 配置
admin/frontend/package.json       ✅ 依賴管理
admin/frontend/ENV_README.md      ✅ 環境配置說明
```

### 後端 API (backend/api/admin/)
```
backend/api/admin/
├── login.php                     ✅ 管理員登入
├── logout.php                    ✅ 管理員登出
├── me.php                        ✅ 管理員資訊
├── tasks.php                     ✅ 任務管理 API
├── support/                      ✅ 客服相關 API
├── dispute-chat-messages.php     ✅ 爭議聊天訊息
├── support-chat-rooms.php        ✅ 客服聊天室
├── referral-events.php           ✅ 推薦事件
└── users/                        ✅ 用戶管理相關 API
    ├── referral-info.php         ✅ 推薦資訊
    ├── review.php                ✅ 用戶審核
    ├── verification.php          ✅ 用戶驗證
    └── point-transactions.php    ✅ 點數交易
```

### 工具文件
```
backend/utils/ReferralCodeGenerator.php  ✅ 推薦碼生成器
backend/create_admin.php                 ✅ 管理員創建腳本
router.php                               ✅ PHP 路由器
```

## ❌ 不應該推送的文件

### 測試文件
```
❌ test_*.php                     # 所有測試文件
❌ test_*.html                    # 測試 HTML 文件
❌ backend/test/                  # 測試目錄
❌ backend/test_admin_apis.php    # 管理員 API 測試
❌ backend/test_admin_password.php # 管理員密碼測試
❌ backend/test_login.php         # 登入測試
```

### 第三方登入相關
```
❌ GOOGLE_OAUTH_FIX.md           # Google OAuth 修復文件
❌ docs/第三方/                   # 第三方登入文檔
❌ backend/api/auth/google-*.php  # Google 登入相關
❌ lib/auth/services/third_party_auth_service.dart
❌ lib/auth/pages/auth_callback_page.dart
❌ web/js/                       # Web JS 文件
```

### 執行紀錄與日誌
```
❌ *.log                         # 所有日誌文件
❌ ngrok.log                     # Ngrok 日誌
❌ server.log                    # 服務器日誌
❌ flutter_01.log                # Flutter 日誌
❌ .ngrok_pid                    # Ngrok PID 文件
```

### 備份文件
```
❌ *.backup                      # 備份文件
❌ *.bak*                        # 備份文件
❌ *_backup_*                    # 帶備份標記的文件
❌ config_backup_*/              # 配置備份目錄
❌ oauth_temp_users_backup_*.sql # OAuth 用戶備份
```

### 環境配置
```
❌ .env*                         # 環境變數文件
❌ backend/.env.backup.*         # 環境變數備份
❌ admin/.env                    # Laravel 環境變數
```

### 敏感文檔
```
❌ docs/優先執行/                 # 包含敏感配置的文檔
❌ docs/security/WEB_OAUTH_SECURITY_GUIDE.md
```

## 🔧 推送前檢查步驟

1. **檢查 .gitignore 規則**
   ```bash
   # 確認 .gitignore 正確排除敏感文件
   git check-ignore test_*.php
   git check-ignore *.log
   git check-ignore .env*
   ```

2. **查看待推送文件**
   ```bash
   # 查看所有變更文件
   git status --porcelain
   
   # 查看具體變更內容
   git diff --name-only
   ```

3. **分階段添加文件**
   ```bash
   # 只添加管理員後台相關文件
   git add admin/app/Http/Controllers/Admin/
   git add admin/frontend/src/
   git add admin/routes/api.php
   git add backend/api/admin/
   git add backend/utils/ReferralCodeGenerator.php
   git add router.php
   ```

4. **最終檢查**
   ```bash
   # 確認暫存區文件
   git diff --cached --name-only
   
   # 確認沒有敏感文件
   git diff --cached --name-only | grep -E "(test_|\.log|\.env|oauth|google)"
   ```

## 📝 提交訊息建議
```
feat(admin): 完成管理員後台系統整合

- 統一 Vue 前端與 Laravel 後端 API 路由
- 修復用戶管理、任務管理、爭議處理功能
- 優化客服聊天室與支援系統
- 建立完整的管理員權限控制
- 對齊前後端數據字段命名規範

影響範圍：
- admin/frontend/: Vue.js 管理員前端
- admin/app/Http/Controllers/Admin/: Laravel 控制器
- backend/api/admin/: PHP 管理員 API
```

## ⚠️ 注意事項

1. **絕對不要推送**：
   - 包含 OAuth 憑證的文件
   - 測試文件和調試腳本
   - 日誌和執行紀錄
   - 環境變數和敏感配置

2. **推送前確認**：
   - 所有 API 端點都已測試正常
   - 前後端數據格式已對齊
   - 沒有硬編碼的敏感資訊

3. **推送後驗證**：
   - 確認生產環境配置正確
   - 驗證管理員登入功能
   - 測試主要管理功能正常運作
