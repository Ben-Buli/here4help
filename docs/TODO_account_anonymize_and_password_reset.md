# TODO: Account Anonymize + Admin Block + Laravel Mail Reset

## 目的與決策
- 刪除帳號時不保留原始 email。
- 管理員刪除的帳號不可重新註冊。
- 忘記密碼改走 Laravel Mail（使用 email_verification_tokens）。

## 影響範圍
- Backend PHP API: 刪除帳號、登入、第三方登入/註冊、OAuth signup。
- 資料表：新增 blocked_emails / blocked_identities。
- Laravel：新增忘記密碼 API（public）。
- Flutter：忘記密碼入口與 API 串接（之後實作）。

## 新增/修改檔案預估

### Backend (PHP)
- `backend/api/account/delete.php`
  - 刪除帳號時匿名化 `users.email`。
  - 依刪除類型（admin vs user）決定是否寫入 blocked 表。
  - 清理 `user_identities`（user 自刪需釋放唯一鍵）。
- `backend/api/auth/register.php`
- `backend/api/auth/register-with-student-id.php`
- `backend/api/auth/register_with_identity.php`
- `backend/api/auth/register-oauth.php`
- `backend/api/auth/register-oauth-with-student-id.php`
  - 註冊前先檢查 blocked_emails。
- `backend/api/auth/oauth-signup.php`
  - 補 permission/blocked 檢查，避免已刪除帳號被綁回。
- `backend/api/auth/google-login.php`
- `backend/api/auth/facebook-login.php`
- `backend/api/auth/apple-login.php`
  - 新用戶流程前檢查 blocked_emails / blocked_identities。
- `backend/utils/Response.php`（視需求）
  - 若要統一回應碼/訊息，可擴增常用錯誤碼。
- `database_fixes/*` 或 `docs/Database_Structure.sql`
  - 新增資料表 SQL 版本控管。

### Laravel (admin/)
- `admin/routes/api.php` 或 `admin/routes/web.php`
  - 新增 public API: `POST /api/password/forgot`。
- `admin/app/Http/Controllers/PasswordResetController.php`（新增）
  - 產生 token、寫入 `email_verification_tokens`、寄信。
- `admin/app/Mail/PasswordResetMail.php`（新增）
  - Mail template + reset link。
- `admin/resources/views/emails/password_reset.blade.php`（新增）
  - 忘記密碼 email 內容。
- `.env` / `env.example`
  - 新增/更新 `MAIL_*` 與 `PASSWORD_RESET_URL`。

### Flutter (後續實作)
- `lib/auth/pages/login_page.dart`
  - 確認忘記密碼入口與流程。

## 資料結構調整
1) 新增 `blocked_emails`
```
id (PK), email (unique), reason, blocked_by, blocked_at, source
```

2) 新增 `blocked_identities`
```
id (PK), provider, provider_user_id (unique), reason, blocked_by, blocked_at, source
```

## 重要變數/判斷邏輯
- 匿名化格式（不保留原始 email）
  - `deleted_{YYYYMMDD}_u{userId}_{rand}@deleted.invalid`
  - 例：`deleted_20260119_u1001_ab12cd34@deleted.invalid`
- 管理員刪除：
  - 匿名化 email + 寫入 blocked_emails/blocked_identities。
  - 重新註冊時直接拒絕。
- 使用者自刪：
  - 匿名化 email + 釋放 `user_identities`（可重新註冊）。
- 註冊/第三方註冊：
  - 先查 blocked_emails/blocked_identities，再進行既有流程。
- OAuth signup：
  - 若 email 對應的 user.permission 為刪除狀態，拒絕綁定。

## 風險與驗證
- 風險：匿名化後資料追溯需求降低。
  - 替代：blocked 表保留封鎖資訊。
- 驗證：
  - 自刪帳號後可用相同 email 重新註冊。
  - 管理員刪除後，email/provider 無法再註冊或綁定。
  - 忘記密碼 email 能成功寄出並重設。

## 紀錄區塊
- [x] 建立 blocked_emails 表（migration + DB 結構文件）
- [x] 建立 blocked_identities 表（migration + DB 結構文件）
- [x] 更新 delete.php 匿名化（自刪）與釋放第三方綁定
- [x] 補齊註冊、OAuth signup、第三方登入的 blocked 檢查
- [x] 管理員刪除時匿名化 + 寫入 blocked + 移除第三方綁定
- [x] 新增 Laravel 忘記密碼 API 與 Mail 模板
- [x] Flutter 忘記密碼 API 改走 Laravel public API

## 未完成 / 需確認
- 需執行 Laravel migration 建立 blocked_* 表
- 確認 MAIL_* 與 PASSWORD_RESET_PAGE_URL 設定
- 確認忘記密碼入口 UI 是否已在登入頁對應
