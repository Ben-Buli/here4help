# Here4Help 完整資料庫部署指南 - MySQL 5.7.44 相容版本

> 將完整的 Here4Help 資料庫部署到 cPanel MySQL 5.7.44 環境

## 📋 部署文件清單

### 1. 主要文件
- **`hero4helpdemofhs_hero4help_complete_mysql57.sql`** (394KB, 4265行)
  - 包含所有 69 個表格的創建語句
  - 包含所有資料插入語句
  - 已修正 MySQL 5.7.44 相容性問題

### 2. 外鍵約束文件
- **`complete_foreign_keys_mysql57.sql`** (5.6KB, 165行)
  - 包含所有外鍵約束
  - 包含錯誤處理和驗證
  - 需要在表格創建後單獨執行

## 🔧 主要修正項目

### 1. **JSON 欄位修正**
```sql
-- 修正前
`old_data` json DEFAULT NULL,
`new_data` json DEFAULT NULL,
`raw_data` json DEFAULT NULL,
`answers_json` json DEFAULT NULL,

-- 修正後
`old_data` TEXT DEFAULT NULL COMMENT 'JSON 資料 (MySQL 5.7.44 使用 TEXT)',
`new_data` TEXT DEFAULT NULL COMMENT 'JSON 資料 (MySQL 5.7.44 使用 TEXT)',
`raw_data` TEXT DEFAULT NULL COMMENT '完整第三方回傳的原始資料 (JSON) - MySQL 5.7.44 使用 TEXT',
`answers_json` TEXT DEFAULT NULL COMMENT 'JSON 資料 (MySQL 5.7.44 使用 TEXT)',
```

### 2. **Generated Column 語法修正**
```sql
-- 修正前
`end_datetime` datetime NOT NULL DEFAULT ((now() + interval 1 hour)),

-- 修正後
`end_datetime` datetime NOT NULL COMMENT '結束時間，由程式或 SQL 指定',
```

### 3. **外鍵約束分離**
- 將所有外鍵約束移至單獨文件
- 避免表格創建時的外鍵約束錯誤
- 提供完整的錯誤處理機制

## 🚀 cPanel 部署步驟

### 步驟 1：準備 cPanel 環境

#### 1.1 登入 cPanel
1. 訪問：`https://hero4help.demofhs.com:2083`
2. 使用你的 cPanel 帳號登入

#### 1.2 創建資料庫
1. 點擊 "MySQL 資料庫"
2. 創建資料庫：`hero4helpdemofhs_hero4help`
3. 創建用戶：`hero4help_user`
4. 設定密碼並記住
5. 將用戶添加到資料庫，設定所有權限

### 步驟 2：執行主 SQL 文件

#### 2.1 上傳主文件
1. 在 cPanel 中找到 "phpMyAdmin"
2. 選擇目標資料庫
3. 點擊 "匯入" (Import)
4. 選擇 `hero4helpdemofhs_hero4help_complete_mysql57.sql`
5. 點擊 "執行" (Go)

#### 2.2 檢查執行結果
- 確認所有 69 個表格創建成功
- 檢查是否有錯誤訊息
- 確認資料插入成功

### 步驟 3：執行外鍵約束文件

#### 3.1 上傳外鍵約束文件
1. 在 phpMyAdmin 中選擇同一資料庫
2. 點擊 "匯入" (Import)
3. 選擇 `complete_foreign_keys_mysql57.sql`
4. 點擊 "執行" (Go)

#### 3.2 檢查外鍵約束
- 確認所有外鍵約束創建成功
- 檢查驗證查詢結果
- 確認沒有外鍵約束錯誤

## 📊 資料庫結構概覽

### 核心表格 (69 個表格)

#### 管理員系統
- `admins` - 管理員帳號
- `admin_activity_logs` - 管理員活動日誌
- `admin_login_logs` - 管理員登入日誌
- `admin_roles` - 管理員角色
- `admin_role_permissions` - 角色權限

#### 用戶系統
- `users` - 用戶資料
- `oauth_temp_users` - OAuth 臨時用戶
- `email_verification_tokens` - 郵箱驗證
- `password_reset_tokens` - 密碼重設

#### 任務系統
- `tasks` - 任務資料
- `task_statuses` - 任務狀態
- `task_applications` - 任務應徵
- `application_questions` - 應徵問題
- `task_disputes` - 任務爭議

#### 聊天系統
- `chat_rooms` - 聊天室
- `chat_messages` - 聊天訊息
- `chat_reads` - 已讀狀態
- `chat_reports` - 聊天檢舉

#### 通知系統
- `notification_templates` - 通知模板
- `notification_preferences` - 通知偏好
- `notification_queue` - 通知佇列
- `notification_logs` - 通知日誌
- `notification_stats` - 通知統計

#### 財務系統
- `point_transactions` - 點數交易
- `point_deposit_requests` - 點數儲值申請
- `wallet_transactions` - 錢包交易
- `task_completion_points_fee_settings` - 任務完成手續費

#### 媒體系統
- `media_files` - 媒體檔案
- `media_access_logs` - 媒體訪問日誌

#### 推薦系統
- `referral_events` - 推薦事件

#### 系統表格
- `migrations` - Laravel 遷移
- `cache` - 快取
- `cache_locks` - 快取鎖
- `jobs` - 任務佇列
- `job_batches` - 任務批次
- `failed_jobs` - 失敗任務
- `laravel_sessions` - Laravel 會話

#### 備份表格
- 多個 `*_backup_*` 表格用於資料備份

## 🔍 相容性檢查清單

### MySQL 5.7.44 相容性
- [x] 移除所有 JSON 欄位，改為 TEXT
- [x] 移除 Generated Column 語法
- [x] 分離外鍵約束到單獨文件
- [x] 統一字符集為 utf8mb4
- [x] 確保所有語法符合 MySQL 5.7.44

### 資料完整性
- [x] 保留所有原始資料
- [x] 保持所有表格結構
- [x] 維持所有索引和外鍵關係
- [x] 確保資料類型正確

### 部署安全性
- [x] 分離外鍵約束避免創建錯誤
- [x] 添加錯誤處理機制
- [x] 提供驗證查詢
- [x] 包含完整的部署指南

## ⚠️ 注意事項

### 1. **執行順序**
- 必須先執行主文件創建表格
- 再執行外鍵約束文件
- 順序錯誤會導致外鍵約束失敗

### 2. **JSON 欄位處理**
- 所有 JSON 欄位已改為 TEXT
- 在 PHP 代碼中需要使用 `json_encode()` 和 `json_decode()`
- 建議使用 `JsonHelper` 工具類處理

### 3. **end_datetime 欄位**
- 移除了 DEFAULT 值
- 必須在程式或 SQL 中明確指定值
- 建議使用 `DATE_ADD(NOW(), INTERVAL 1 HOUR)` 計算

### 4. **外鍵約束**
- 如果外鍵約束創建失敗，檢查表格是否存在
- 確認欄位類型匹配
- 檢查字符集是否一致

## 🎯 部署成功指標

### 表格創建
- [ ] 所有 69 個表格創建成功
- [ ] 沒有語法錯誤
- [ ] 所有資料插入成功

### 外鍵約束
- [ ] 所有外鍵約束創建成功
- [ ] 驗證查詢返回正確結果
- [ ] 沒有外鍵約束錯誤

### 功能測試
- [ ] 用戶註冊/登入正常
- [ ] 任務創建/應徵正常
- [ ] 聊天功能正常
- [ ] 管理員後台正常

## 📞 技術支援

如果遇到問題：
1. 檢查 cPanel 錯誤日誌
2. 確認 MySQL 版本為 5.7.44
3. 檢查資料庫用戶權限
4. 參考錯誤訊息進行除錯

---

**部署完成後記得：**
- 更新應用程式的資料庫配置
- 測試所有功能正常運作
- 設定定期備份策略
- 監控系統效能

**版本**: MySQL 5.7.44 相容版本  
**更新日期**: 2025-09-15  
**維護者**: Here4Help 開發團隊
