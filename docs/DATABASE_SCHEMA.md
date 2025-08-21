
# Here4Help 資料庫文件（重編版，含現況與必須異動）

> 目的：提供一份「可維運、可開發」的單一事實來源（Single Source of Truth）。本文件分為 **As-Is（目前實際資料庫）** 與 **To-Be（必要一致化異動）**。所有 API 與前端必須以本文件為準。

---

## 0) 全域約定

- **DB 名稱**：`hero4helpdemofhs_hero4help`
- **字元集 / Collation**：`utf8mb4` / `utf8mb4_unicode_ci`
- **引擎**：InnoDB
- **時間欄位慣例**：`created_at`、`updated_at`（`updated_at` 預設 `ON UPDATE CURRENT_TIMESTAMP`）
- **軟刪除**：目前未導入，若未來需要請新增 `deleted_at`。

---

## 1) As‑Is 概觀（來自目前 SQL Dump）

> 來源：`hero4helpdemofhs_hero4helpSCHEMA.sql`（完整 `CREATE TABLE` 內容已萃取）。此處列出核心表格與用途，供對照。

### 1.1 使用者
- `users`：使用者主檔，`id` 為 BIGINT UNSIGNED，自增。`email` 唯一。
- **新增欄位**：`nickname`、`gender`、`country`、`address`、`is_permanent_address`、`primary_language`、`school`、`permission`、`terms_accepted_at`、`language_requirement`、`referral_code`
- **狀態擴充**：`enum('active','pending_review','rejected','banned','inactive')`

### 1.2 任務（Tasks）
- `tasks`：任務主檔，`id` 為 `varchar(36)`（UUID），`status_id` 數值對 `task_statuses.id`。
- **新增欄位**：`participant_id`（替代舊的 `acceptor_id`）、`start_datetime`、`end_datetime`、`creator_confirmed`、`acceptor_confirmed`、`cancel_reason`、`fail_reason`、`hashtags`
- `task_statuses`：任務狀態字典，含 `code` 與 `display_name`。
- **新增欄位**：`progress_ratio`、`sort_order`、`include_in_unread`、`is_active`

> **差異提醒**：現行 `task_applications.status` 已更新為 `ENUM('applied','accepted','rejected','pending','completed','cancelled','dispute')`，並新增 `accepted_flag` 產生欄位確保單一受雇者。

- `task_applications`：任務應徵關聯（已更新狀態 Enum 並新增 `accepted_flag`）。
- `application_questions`：任務申請額外提問與回覆。

### 1.3 聊天（Chat）
- `chat_rooms`：1v1 聊天室（`creator_id` ↔ `participant_id` 對應 `users.id`，綁定 `task_id`）。
- **新增欄位**：`dispute_id`、`type`（支援爭議聊天）
- `chat_messages`：訊息（`kind` = `'text'|'image'|'file'|'system'`）。
- **新增欄位**：`media_url`、`mime_type`（支援媒體訊息）
- `chat_reads`：**已改為**含 `id` 自增主鍵 + `UNIQUE(user_id, room_id)`，紀錄 `last_read_message_id`。

### 1.4 評價 / 點數 / 推薦碼
- `task_ratings`：**新增**雙向評價系統，可追溯到具體的受評者。
- `point_deposit_requests`：**新增**點數充值申請與管理員審核。
- `referral_codes` / `referral_events`：**新增**推薦碼與使用紀錄。

### 1.5 管理與系統
- `admins` / `admin_activity_logs` / `admin_login_logs`：**新增**管理員與稽核系統。
- `cache` / `cache_locks`：**新增**快取與鎖機制。
- `task_logs`：**新增**任務操作歷史記錄，支援審計追蹤。

### 1.6 新增功能模組
- `user_identities`：**新增**第三方登入管理（Google、Facebook、Apple）。
- `student_verifications`：**新增**學生身分驗證系統。
- `user_blocks`：**新增**用戶封鎖功能。
- `task_disputes` / `dispute_status_logs`：**新增**爭議處理系統。

---

## 2) To‑Be 一致化異動（**必做**）

> 下列異動與[聊天模組規格](chat_module_spec.md)對齊，並確保 **角色映射視角**、**未讀計算**、**評分可追溯** 與 **單一受雇者** 的一致性。

### 2.1 應徵狀態（Applications）標準化 ✅ 已完成
- `task_applications.status` **已更新為**：`ENUM('applied','accepted','rejected','pending','completed','cancelled','dispute')`
- **單一受雇者**：**已新增** **產生欄位** `accepted_flag`，僅在 `status='accepted'` 時為 `1`，並建立唯一鍵 `(task_id, accepted_flag)`。

```sql
-- 已完成，無需執行
-- ALTER TABLE `task_applications`
--   MODIFY COLUMN `status` ENUM('applied','accepted','rejected','pending','completed','cancelled','dispute') NOT NULL DEFAULT 'applied';

-- ALTER TABLE `task_applications`
--   ADD COLUMN `accepted_flag` TINYINT
--     AS (CASE WHEN `status` = 'accepted' THEN 1 ELSE NULL END) STORED,
--   ADD UNIQUE KEY `uk_task_one_accept` (`task_id`, `accepted_flag`);
```

> **說明**：確保任務只能有 **一個**被接受的應徵者（DB 層級最後防線）。

### 2.2 任務狀態日誌 ✅ 已完成
- **已新增** `task_logs`，用來記錄任務狀態切換（用於 Pending Confirmation 七日倒數）。

```sql
-- 已完成，無需執行
-- CREATE TABLE IF NOT EXISTS `task_logs` (
--   `id` BIGINT NOT NULL AUTO_INCREMENT,
--   `task_id` VARCHAR(36) NOT NULL,
--   `action` VARCHAR(64) NOT NULL,
--   `old_status` VARCHAR(50) DEFAULT NULL,
--   `new_status` VARCHAR(50) NOT NULL,
--   `admin_id` INT DEFAULT NULL,
--   `user_id` BIGINT UNSIGNED DEFAULT NULL,
--   `description` TEXT,
--   `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
--   PRIMARY KEY (`id`)
-- ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2.3 評分資料模型 ✅ 已完成
- **已新增** `task_ratings`，以 **最終受雇者** 為受評對象，防重複：`(task_id, rater_id, tasker_id)` 唯一。

```sql
-- 已完成，無需執行
-- CREATE TABLE IF NOT EXISTS `task_ratings` (
--   `id` BIGINT NOT NULL AUTO_INCREMENT,
--   `task_id` VARCHAR(36) NOT NULL,
--   `rater_id` BIGINT UNSIGNED NOT NULL,
--   `tasker_id` BIGINT UNSIGNED NOT NULL, -- 受評者 = 最終 accepted 應徵者
--   `rating` TINYINT NOT NULL,
--   `comment` TEXT DEFAULT NULL,
--   `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
--   PRIMARY KEY (`id`),
--   UNIQUE KEY `uk_task_rater_tasker` (`task_id`, `rater_id`, `tasker_id`),
--   KEY `idx_task` (`task_id`),
--   KEY `idx_rater` (`rater_id`),
--   KEY `idx_tasker` (`tasker_id`)
-- ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

> **備註**：若需保留 `reviews` 作為歷史資料，可維持但前端/報表一律改讀 `task_ratings`。

### 2.4 聊天訊息類型補完 ✅ 已完成
- `chat_messages.kind` **已擴充** 為：`ENUM('text','image','file','system')`，其中 `image` 和 `file` 類型的 `content` 僅儲存文字描述，實際檔案 URL 儲存在 `media_url`。

```sql
-- 已完成，無需執行
-- ALTER TABLE `chat_messages`
--   MODIFY COLUMN `kind` ENUM('text','image','file','system') NOT NULL DEFAULT 'text';
```

### 2.5 已讀指標（chat_reads）一致性 ✅ 已完成
- 現況已具備：`id` 自增、`UNIQUE(user_id, room_id)`、`last_read_message_id`。  
- 規範：**所有未讀計算**僅依 `last_read_message_id`（不逐則寫回）。

### 2.6 任務狀態字典（`task_statuses`）比對 ✅ 已完成
- 確保 `task_statuses` 具備下列 code（可依序號）與 `display_name`：  
  `open` / `in_progress` / `pending_confirmation` / `dispute` / `completed` / `closed` / `cancelled`

> 若現有不一致，**請補齊/對齊**，避免頁面映射混亂。

---

## 3) 目標 ER（精簡文字版）

- **users** (1) ——< **tasks**(creator_id)  
- **tasks** (1) ——< **task_applications**(task_id, user_id)  
- **tasks** (1) ——< **chat_rooms**(task_id) ——< **chat_messages**  
- **users** (1) ——< **chat_rooms**(creator_id / participant_id)  
- **users** (1) ——< **chat_messages**(from_user_id)  
- **users** (1) ——< **chat_reads**(user_id, room_id UNIQUE)  
- **tasks** (1) ——< **task_logs**  
- **users** (1) ——< **task_ratings**(rater_id / tasker_id)  
- **users** (1) ——< **referral_codes** ——< **referral_events**  
- **users** (1) ——< **point_deposit_requests**  
- **users** (1) ——< **user_identities**（第三方登入）
- **users** (1) ——< **student_verifications**（學生驗證）
- **users** (1) ——< **user_blocks**（用戶封鎖）
- **tasks** (1) ——< **task_disputes**（爭議處理）
- **admins** (1) ——< **admin_activity_logs**（管理員活動）

---

## 4) 標準化 DDL（To‑Be 完整範本）

> 下列為 **最終一致版本** 的主要表 DDL（可直接對照、或用於初始化測試環境）。

### 4.1 使用者
```sql
CREATE TABLE `users` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255) DEFAULT NULL,
  `nickname` VARCHAR(255) DEFAULT NULL,
  `email` VARCHAR(255) DEFAULT NULL COMMENT '用戶email，第三方登入帳號可為NULL',
  `password` VARCHAR(255) DEFAULT NULL COMMENT '用戶密碼，第三方登入帳號可為NULL',
  `email_verified_at` DATETIME DEFAULT NULL COMMENT 'email 驗證時間',
  `payment_password` VARCHAR(255) DEFAULT NULL,
  `date_of_birth` DATE DEFAULT NULL,
  `gender` ENUM('Male','Female','Non-binary','Genderfluid','Agender','Bigender','Genderqueer','Two-spirit','Other','Prefer not to disclose') NOT NULL DEFAULT 'Prefer not to disclose',
  `country` VARCHAR(255) DEFAULT NULL,
  `address` TEXT,
  `is_permanent_address` TINYINT(1) DEFAULT '0',
  `primary_language` VARCHAR(50) DEFAULT 'English',
  `school` VARCHAR(20) DEFAULT NULL,
  `phone` VARCHAR(20) DEFAULT NULL,
  `permission` int DEFAULT '0' COMMENT '0=新用戶未認證, 1=已認證用戶, 99=管理員, -1=被管理員停權, -2=被管理員軟刪除, -3=用戶自行停權, -4=用戶自行軟刪除',
  `avatar_url` VARCHAR(255) DEFAULT NULL,
  `terms_accepted_at` DATETIME DEFAULT NULL COMMENT '條款接受時間',
  `points` INT DEFAULT NULL,
  `status` ENUM('active','pending_review','rejected','banned','inactive') DEFAULT 'pending_review',
  `language_requirement` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP NULL DEFAULT NULL,
  `updated_at` TIMESTAMP NULL DEFAULT NULL,
  `referral_code` VARCHAR(12) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `uq_users_referral_code_ci` (`referral_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

#### 4.1.1 第三方登入身分（新增）
```sql
CREATE TABLE `user_identities` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `provider` VARCHAR(32) NOT NULL COMMENT '第三方登入提供者：google, facebook, apple',
  `provider_user_id` VARCHAR(191) NOT NULL COMMENT '第三方平台的用戶ID',
  `email` VARCHAR(255) DEFAULT NULL COMMENT '第三方平台提供的email（Apple首次可得，後續可能無）',
  `name` VARCHAR(255) DEFAULT NULL COMMENT '第三方平台提供的姓名',
  `avatar_url` TEXT COMMENT '第三方平台提供的頭像URL',
  `access_token` TEXT COMMENT '存取權杖（僅在需要代呼叫API時保存）',
  `refresh_token` TEXT COMMENT '重新整理權杖',
  `token_expires_at` DATETIME DEFAULT NULL COMMENT '權杖過期時間',
  `raw_profile` JSON DEFAULT NULL COMMENT '原始回應資料備查',
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_provider_uid` (`provider`,`provider_user_id`),
  CONSTRAINT `fk_user_identities_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

#### 4.1.2 學生驗證（新增）
```sql
CREATE TABLE `student_verifications` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `school_name` VARCHAR(255) NOT NULL,
  `student_name` VARCHAR(255) NOT NULL,
  `student_id` VARCHAR(255) NOT NULL,
  `student_id_image_path` VARCHAR(500) NOT NULL,
  `verification_status` ENUM('pending','approved','rejected') DEFAULT 'pending',
  `verification_notes` TEXT,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `student_verifications_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

#### 4.1.3 用戶封鎖（新增）
```sql
CREATE TABLE `user_blocks` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `target_user_id` BIGINT UNSIGNED NOT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_user_target` (`user_id`,`target_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

### 4.2 任務
```sql
CREATE TABLE `tasks` (
  `id` VARCHAR(36) NOT NULL,
  `creator_id` BIGINT UNSIGNED NOT NULL,
  `participant_id` BIGINT UNSIGNED DEFAULT NULL,
  `title` VARCHAR(255) NOT NULL,
  `description` TEXT NOT NULL,
  `reward_point` VARCHAR(10) NOT NULL,
  `location` VARCHAR(255) NOT NULL,
  `task_date` DATE NOT NULL,
  `start_datetime` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `end_datetime` DATETIME NOT NULL DEFAULT ((now() + interval 1 hour)),
  `status_id` INT DEFAULT '1',
  `creator_confirmed` TINYINT(1) DEFAULT '0',
  `acceptor_confirmed` TINYINT(1) DEFAULT '0',
  `cancel_reason` TEXT,
  `fail_reason` TEXT,
  `language_requirement` VARCHAR(50) NOT NULL DEFAULT '',
  `hashtags` TEXT,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_tasks_creator` FOREIGN KEY (`creator_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_tasks_participant` FOREIGN KEY (`participant_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

#### 4.2.1 任務狀態字典
```sql
CREATE TABLE `task_statuses` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(64) NOT NULL,
  `display_name` VARCHAR(128) NOT NULL,
  `progress_ratio` DECIMAL(3,2) NOT NULL DEFAULT '0.00',
  `sort_order` INT NOT NULL DEFAULT '0',
  `include_in_unread` TINYINT(1) NOT NULL DEFAULT '1',
  `is_active` TINYINT(1) NOT NULL DEFAULT '1',
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 4.3 應徵
```sql
CREATE TABLE `task_applications` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `task_id` VARCHAR(36) NOT NULL,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `status` ENUM('applied','accepted','rejected','pending','completed','cancelled','dispute') NOT NULL DEFAULT 'applied',
  `accepted_flag` TINYINT AS (CASE WHEN `status`='accepted' THEN 1 ELSE NULL END) STORED,
  `cover_letter` TEXT,
  `answers_json` JSON DEFAULT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_task_user` (`task_id`,`user_id`),
  UNIQUE KEY `uk_task_one_accept` (`task_id`,`accepted_flag`),
  CONSTRAINT `fk_app_task` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_app_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

#### 4.3.1 申請問題（新增）
```sql
CREATE TABLE `application_questions` (
  `id` VARCHAR(36) NOT NULL,
  `task_id` VARCHAR(36) NOT NULL,
  `application_question` TEXT NOT NULL,
  `applier_reply` TEXT,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `application_questions_ibfk_1` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 4.4 聊天
```sql
CREATE TABLE `chat_rooms` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `task_id` VARCHAR(36) DEFAULT NULL,
  `dispute_id` BIGINT UNSIGNED DEFAULT NULL,
  `creator_id` BIGINT UNSIGNED NOT NULL,
  `participant_id` BIGINT UNSIGNED NOT NULL,
  `type` ENUM('application','task','support','dispute') NOT NULL DEFAULT 'task',
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_task_creator_participant` (`task_id`,`creator_id`,`participant_id`),
  CONSTRAINT `fk_room_creator` FOREIGN KEY (`creator_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_room_dispute` FOREIGN KEY (`dispute_id`) REFERENCES `task_disputes` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_room_participant` FOREIGN KEY (`participant_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_room_task` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

```sql
CREATE TABLE `chat_messages` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `room_id` BIGINT NOT NULL,
  `kind` ENUM('text','image','file','system') DEFAULT 'text',
  `content` TEXT NOT NULL,
  `media_url` VARCHAR(500) DEFAULT NULL,
  `mime_type` VARCHAR(100) DEFAULT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `from_user_id` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_chat_messages_room` FOREIGN KEY (`room_id`) REFERENCES `chat_rooms` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_chat_messages_user` FOREIGN KEY (`from_user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

```sql
CREATE TABLE `chat_reads` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT NOT NULL,
  `room_id` BIGINT NOT NULL,
  `last_read_message_id` BIGINT UNSIGNED NOT NULL DEFAULT '0',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_chat_reads_user_room` (`user_id`,`room_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 4.5 爭議處理（新增）
```sql
CREATE TABLE `task_disputes` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `task_id` VARCHAR(36) NOT NULL,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `status` ENUM('open','in_review','resolved','rejected') DEFAULT 'open',
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `resolved_at` TIMESTAMP NULL DEFAULT NULL,
  `rejected_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_dispute_task` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_dispute_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

```sql
CREATE TABLE `dispute_status_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `dispute_id` BIGINT UNSIGNED NOT NULL,
  `status` ENUM('open','in_review','resolved','rejected') NOT NULL,
  `changed_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `changed_by` BIGINT UNSIGNED DEFAULT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_dsl_dispute` FOREIGN KEY (`dispute_id`) REFERENCES `task_disputes` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 4.6 任務日誌（新增）
```sql
CREATE TABLE `task_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `task_id` VARCHAR(36) NOT NULL,
  `action` VARCHAR(64) NOT NULL,
  `old_status` VARCHAR(50) DEFAULT NULL,
  `new_status` VARCHAR(50) DEFAULT NULL,
  `admin_id` INT DEFAULT NULL,
  `user_id` BIGINT UNSIGNED DEFAULT NULL,
  `description` TEXT,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_task_logs_admin` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_task_logs_task` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_task_logs_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 4.7 評分（新增）
```sql
CREATE TABLE `task_ratings` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `task_id` VARCHAR(36) NOT NULL,
  `rater_id` BIGINT UNSIGNED NOT NULL,
  `tasker_id` BIGINT UNSIGNED NOT NULL,
  `rating` TINYINT UNSIGNED NOT NULL,
  `comment` TEXT,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_task_rater_tasker` (`task_id`,`rater_id`,`tasker_id`),
  CONSTRAINT `fk_task_ratings_rater` FOREIGN KEY (`rater_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_task_ratings_task` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_task_ratings_tasker` FOREIGN KEY (`tasker_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 4.8 點數與推薦系統（新增）
```sql
CREATE TABLE `point_deposit_requests` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `added_value` INT NOT NULL COMMENT '儲值點數',
  `status` ENUM('pending','approved','rejected') DEFAULT 'pending',
  `reply_description` TEXT COMMENT '審核回覆說明',
  `approver_id` INT DEFAULT NULL COMMENT '審核管理員ID',
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `point_deposit_requests_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `point_deposit_requests_ibfk_2` FOREIGN KEY (`approver_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

```sql
CREATE TABLE `referral_codes` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `referral_code` VARCHAR(10) NOT NULL,
  `is_used` TINYINT(1) DEFAULT '0',
  `used_by_user_id` BIGINT UNSIGNED DEFAULT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `referral_code` (`referral_code`),
  CONSTRAINT `referral_codes_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `referral_codes_ibfk_2` FOREIGN KEY (`used_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 4.9 管理員系統（新增）
```sql
CREATE TABLE `admins` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `username` VARCHAR(50) NOT NULL,
  `email` VARCHAR(255) NOT NULL,
  `password` VARCHAR(255) NOT NULL,
  `full_name` VARCHAR(100) NOT NULL,
  `role_id` BIGINT UNSIGNED DEFAULT NULL,
  `status` ENUM('active','reset','inactive','suspended') DEFAULT 'active',
  `last_login` TIMESTAMP NULL DEFAULT NULL,
  `login_attempts` INT DEFAULT '0',
  `locked_until` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  UNIQUE KEY `email` (`email`),
  CONSTRAINT `fk_admin_role` FOREIGN KEY (`role_id`) REFERENCES `admin_roles` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 4.10 系統功能（新增）
```sql
CREATE TABLE `cache` (
  `key` VARCHAR(255) NOT NULL,
  `value` MEDIUMTEXT NOT NULL,
  `expiration` INT NOT NULL,
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 4.11 客服聊天室事件（新增）
CREATE TABLE `support_events` (
  `id` bigint NOT NULL,
  `chat_room_id` bigint NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL COMMENT '客戶 ID',
  `admin_id` int DEFAULT NULL COMMENT '客服 ID',
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `status` enum('open','in_progress','resolved','closed_by_customer') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'open',
  `closed_at` datetime DEFAULT NULL,
  `rating` tinyint DEFAULT NULL,
  `review` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

### 4.11.1 客服聊天室事件_log （新增）
CREATE TABLE `support_event_logs` (
  `id` bigint NOT NULL,
  `event_id` bigint NOT NULL,
  `admin_id` int DEFAULT NULL COMMENT '操作人',
  `old_status` enum('open','in_progress','resolved','closed_by_customer') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `new_status` enum('open','in_progress','resolved','closed_by_customer') COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

---

## 5) 外鍵建議（可選，但建議在新環境強化）
> 生產環境若擔心歷史髒資料導致 FK 失敗，可先以 **應用層與定時清理** 保護，之後逐步補上 FK。

- `tasks.creator_id` → `users(id)`
- `task_applications.task_id` → `tasks(id)`；`task_applications.user_id` → `users(id)`
- `chat_rooms.task_id` → `tasks(id)`；`chat_rooms.creator_id/participant_id` → `users(id)`
- `chat_messages.room_id` → `chat_rooms(id)`；`chat_messages.from_user_id` → `users(id)`
- `chat_reads.room_id` → `chat_rooms(id)`；`chat_reads.user_id` → `users(id)`
- `task_ratings.tasker_id` / `rater_id` → `users(id)`；`task_ratings.task_id` → `tasks(id)`
- `user_identities.user_id` → `users(id)`
- `student_verifications.user_id` → `users(id)`
- `task_disputes.task_id` → `tasks(id)`；`task_disputes.user_id` → `users(id)`

---

## 6) 索引策略（與查詢對齊）
- 取房最新訊息 / 分頁：`chat_messages(room_id, id)`
- 計未讀（對方訊息 + 分界）：`chat_messages(room_id, from_user_id, id)` + `chat_reads(user_id, room_id)`
- 查我的所有房：`chat_rooms(creator_id)`、`chat_rooms(participant_id)`、`chat_rooms(task_id)`
- 倒數查詢：`task_logs(task_id, created_at)`
- 第三方登入查詢：`user_identities(provider, provider_user_id)`
- 學生驗證查詢：`student_verifications(user_id, verification_status)`

---

## 7) 遷移清單（按順序執行）

### ✅ 已完成項目
1. **Applications 標準化** - `task_applications.status` 已更新，`accepted_flag` 已新增
2. **新增 `task_logs`** - 任務操作歷史記錄已建立
3. **擴充 `chat_messages.kind`** - 已支援 `'image'`、`'file'`、`'system'`
4. **導入 `task_ratings`** - 雙向評分系統已建立
5. **新增管理員系統** - `admins`、`admin_roles`、`admin_activity_logs` 已建立
6. **新增第三方登入** - `user_identities` 已建立
7. **新增爭議處理** - `task_disputes`、`dispute_status_logs` 已建立
8. **新增點數系統** - `point_deposit_requests` 已建立
9. **新增推薦碼系統** - `referral_codes`、`referral_events` 已建立

### 🔄 建議優化項目
1. **索引補齊**（見 §6）
2. **資料清理** - 清理測試資料和無效記錄
3. **效能監控** - 啟用慢查詢日誌並定期調優

---

## 8) 資料品質與一致性守則

- **未讀計算**：一律以 `chat_reads.last_read_message_id` 為分界；不逐則寫回。
- **角色映射視角**：後端回傳 `mapped_status` + `raw_task_status` + `application_status`；前端不自行推導。
- **單一受雇者**：違反唯一鍵 → 回 `409`，應用層顯示友善訊息。
- **倒數轉態**：由 worker/cron 負責，**冪等**（重試不會重覆轉點）。
- **第三方登入**：支援 Google、Facebook、Apple 登入，自動建立 `user_identities` 記錄。
- **學生驗證**：支援學生身分驗證，管理員可審核驗證申請。

---

## 9) 版本維運
- **備份**：每日
- **慢查詢**：啟用日誌並定期調優索引
- **資料清理**：cache/logs 定期清理
- **Schema 版本標記**：以 migration id / release tag 標註

---

## 10) 新增功能模組說明

### 10.1 第三方登入系統
- 支援 Google、Facebook、Apple 登入
- 自動建立 `user_identities` 記錄
- 支援權杖管理和重新整理

### 10.2 學生驗證系統
- 支援學生身分驗證
- 管理員可審核驗證申請
- 支援多種驗證狀態

### 10.3 爭議處理系統
- 支援任務爭議申訴
- 管理員可介入處理
- 完整的爭議狀態追蹤

### 10.4 管理員權限系統
- 支援角色權限管理
- 完整的活動日誌記錄
- 登入安全保護機制

### 10.5 點數與推薦系統
- 支援點數充值申請
- 管理員可審核充值
- 推薦碼生成與使用追蹤

---

> 本文件與 `chat_module_spec.md` 相互對應。當兩份文件衝突時，以 **To‑Be**（本文件 §2 / §4 / §7）為最終準則。

> **重要提醒**：所有新增功能已整合到現有資料庫結構中，無需額外遷移步驟。建議在測試環境中驗證所有功能正常運作後，再部署到生產環境。
