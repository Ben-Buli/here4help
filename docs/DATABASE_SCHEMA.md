
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

> 來源：`extracted_schema.md`（完整 `CREATE TABLE` 內容已萃取）。此處列出核心表格與用途，供對照。

### 1.1 使用者
- `users`：使用者主檔，`id` 為 BIGINT UNSIGNED，自增。`email` 唯一。

### 1.2 任務（Tasks）
- `tasks`：任務主檔，`id` 為 `varchar(36)`（UUID），`status_id` 數值對 `task_statuses.id`。
- `task_statuses`：任務狀態字典，含 `code` 與 `display_name`。

> **差異提醒**：現行 `task_applications.status` 為 `ENUM('pending','approved','rejected','completed','cancelled')`（與規格不一致）。

- `task_applications`：任務應徵關聯（現況的 `status` Enum 如上）。
- `application_questions`：任務申請額外提問與回覆。

### 1.3 聊天（Chat）
- `chat_rooms`：1v1 聊天室（`creator_id` ↔ `participant_id` 對應 `users.id`，綁定 `task_id`）。
- `chat_messages`：訊息（`kind` = `'user'|'system'|'applyMessage'`）。
- `chat_reads`：**已改為**含 `id` 自增主鍵 + `UNIQUE(user_id, room_id)`，紀錄 `last_read_message_id`。

### 1.4 評價 / 點數 / 推薦碼
- `reviews`：單向評價（現況用表）。
- `points` / `point_requests`：點數流水與充值申請。
- `referral_codes` / `referral_uses`：推薦碼與使用紀錄。

### 1.5 管理與系統
- `admins` / `admin_activity_logs` / `admin_login_logs`：管理員與稽核。
- `cache` / `cache_locks`：快取與鎖。

---

## 2) To‑Be 一致化異動（**必做**）

> 下列異動與[聊天模組規格](chat_module_spec.md)對齊，並確保 **角色映射視角**、**未讀計算**、**評分可追溯** 與 **單一受雇者** 的一致性。

### 2.1 應徵狀態（Applications）標準化
- 將 `task_applications.status` **改為**：`ENUM('applied','accepted','rejected')`（簡潔、與流程一致）。
- 強制 **單一受雇者**：新增 **產生欄位** `accepted_flag`，僅在 `status='accepted'` 時為 `1`，並建立唯一鍵 `(task_id, accepted_flag)`。

```sql
ALTER TABLE `task_applications`
  MODIFY COLUMN `status` ENUM('applied','accepted','rejected') NOT NULL DEFAULT 'applied';

ALTER TABLE `task_applications`
  ADD COLUMN `accepted_flag` TINYINT
    AS (CASE WHEN `status` = 'accepted' THEN 1 ELSE NULL END) STORED,
  ADD UNIQUE KEY `uk_task_one_accept` (`task_id`, `accepted_flag`);
```

> **說明**：確保任務只能有 **一個**被接受的應徵者（DB 層級最後防線）。

### 2.2 任務狀態日誌（倒數用）
- 新增 `task_status_logs`，用來記錄任務狀態切換（用於 Pending Confirmation 七日倒數）。

```sql
CREATE TABLE IF NOT EXISTS `task_status_logs` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `task_id` VARCHAR(36) NOT NULL,
  `from_status_id` INT DEFAULT NULL,
  `to_status_id` INT NOT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_task_status_time` (`task_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2.3 評分資料模型（可追溯到受評者）
- 新增 / 取代 `reviews` 為 `task_ratings`，以 **最終受雇者** 為受評對象，防重複：`(task_id, rater_id, tasker_id)` 唯一。

```sql
CREATE TABLE IF NOT EXISTS `task_ratings` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `task_id` VARCHAR(36) NOT NULL,
  `rater_id` BIGINT UNSIGNED NOT NULL,
  `tasker_id` BIGINT UNSIGNED NOT NULL, -- 受評者 = 最終 accepted 應徵者
  `rating` TINYINT NOT NULL,
  `comment` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_task_rater_tasker` (`task_id`, `rater_id`, `tasker_id`),
  KEY `idx_task` (`task_id`),
  KEY `idx_rater` (`rater_id`),
  KEY `idx_tasker` (`tasker_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

> **備註**：若需保留 `reviews` 作為歷史資料，可維持但前端/報表一律改讀 `task_ratings`。

### 2.4 聊天訊息類型補完（圖片訊息）
- 將 `chat_messages.kind` **擴充** 為：`ENUM('user','system','applyMessage','image')`，其中 `image` 類型的 `content` 僅儲存圖片 URL。

```sql
ALTER TABLE `chat_messages`
  MODIFY COLUMN `kind` ENUM('user','system','applyMessage','image') NOT NULL DEFAULT 'user';
```

### 2.5 已讀指標（chat_reads）一致性
- 現況已具備：`id` 自增、`UNIQUE(user_id, room_id)`、`last_read_message_id`。  
- 規範：**所有未讀計算**僅依 `last_read_message_id`（不逐則寫回）。

### 2.6 任務狀態字典（`task_statuses`）比對
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
- **tasks** (1) ——< **task_status_logs**  
- **users** (1) ——< **task_ratings**(rater_id / tasker_id)  
- **users** (1) ——< **referral_codes** ——< **referral_uses**  
- **users** (1) ——< **points** / **point_requests**  

---

## 4) 標準化 DDL（To‑Be 完整範本）

> 下列為 **最終一致版本** 的主要表 DDL（可直接對照、或用於初始化測試環境）。


### 4.1 使用者
```sql
CREATE TABLE `users` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255) NOT NULL,
  `email` VARCHAR(255) NOT NULL UNIQUE,
  `password` VARCHAR(255) NOT NULL,
  `avatar_url` VARCHAR(500) DEFAULT NULL,
  `phone` VARCHAR(20) DEFAULT NULL,
  `status` ENUM('active','inactive','banned') DEFAULT 'active',
  `email_verified_at` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```
> user_identities：用於管理第三方登入相關資訊
```sql
-- user_identities 資料結構

CREATE TABLE `user_identities` (
  `id` bigint UNSIGNED NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `provider` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '第三方登入提供者：google, facebook, apple',
  `provider_user_id` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '第三方平台的用戶ID',
  `email` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '第三方平台提供的email（Apple首次可得，後續可能無）',
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '第三方平台提供的姓名',
  `avatar_url` text COLLATE utf8mb4_unicode_ci COMMENT '第三方平台提供的頭像URL',
  `access_token` text COLLATE utf8mb4_unicode_ci COMMENT '存取權杖（僅在需要代呼叫API時保存）',
  `refresh_token` text COLLATE utf8mb4_unicode_ci COMMENT '重新整理權杖',
  `token_expires_at` datetime DEFAULT NULL COMMENT '權杖過期時間',
  `raw_profile` json DEFAULT NULL COMMENT '原始回應資料備查',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- 已傾印資料表的索引
--

--
-- 資料表索引 `user_identities`
--
ALTER TABLE `user_identities`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_provider_uid` (`provider`,`provider_user_id`),
  ADD KEY `idx_user_provider` (`user_id`,`provider`),
  ADD KEY `idx_provider_user_id` (`provider_user_id`),
  ADD KEY `idx_email` (`email`);

--
-- 在傾印的資料表使用自動遞增(AUTO_INCREMENT)
--
-- 使用資料表自動遞增(AUTO_INCREMENT) `user_identities`
--
ALTER TABLE `user_identities`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

-- 已傾印資料表的限制式
--
-- 資料表的限制式 `user_identities`
--
ALTER TABLE `user_identities`
  ADD CONSTRAINT `fk_user_identities_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;
COMMIT;
```

### 4.2 任務
```sql
CREATE TABLE `tasks` (
  `id` VARCHAR(36) NOT NULL,
  `creator_id` BIGINT UNSIGNED NOT NULL,
  `title` VARCHAR(255) NOT NULL,
  `description` TEXT NOT NULL,
  `location` VARCHAR(255) NOT NULL,
  `budget_min` DECIMAL(10,2) NOT NULL,
  `budget_max` DECIMAL(10,2) NOT NULL,
  `start_datetime` DATETIME NOT NULL,
  `end_datetime` DATETIME NOT NULL,
  `status_id` INT NOT NULL DEFAULT 1,
  `popular` TINYINT(1) DEFAULT 0,
  `new` TINYINT(1) DEFAULT 1,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_tasks_creator` (`creator_id`),
  KEY `idx_tasks_status` (`status_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `task_statuses` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(50) NOT NULL,
  `display_name` VARCHAR(100) NOT NULL,
  `progress_ratio` DECIMAL(3,2) DEFAULT 0.00,
  `sort_order` INT DEFAULT 0,
  `include_in_unread` TINYINT(1) DEFAULT 1,
  `is_active` TINYINT(1) DEFAULT 1,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 4.3 應徵
```sql
CREATE TABLE `task_applications` (
  `id` VARCHAR(36) NOT NULL,
  `task_id` VARCHAR(36) NOT NULL,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `status` ENUM('applied','accepted','rejected') NOT NULL DEFAULT 'applied',
  `accepted_flag` TINYINT AS (CASE WHEN `status`='accepted' THEN 1 ELSE NULL END) STORED,
  `cover_letter` TEXT,
  `proposed_budget` DECIMAL(10,2) DEFAULT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_app_task` (`task_id`),
  KEY `idx_app_user` (`user_id`),
  UNIQUE KEY `uk_task_one_accept` (`task_id`, `accepted_flag`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `application_questions` (
  `id` VARCHAR(36) NOT NULL,
  `task_id` VARCHAR(36) NOT NULL,
  `application_question` TEXT NOT NULL,
  `applier_reply` TEXT,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 4.4 聊天
```sql
CREATE TABLE `chat_rooms` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `task_id` VARCHAR(36) NOT NULL,
  `creator_id` BIGINT UNSIGNED NOT NULL,
  `participant_id` BIGINT UNSIGNED NOT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_room_task` (`task_id`),
  KEY `idx_room_creator` (`creator_id`),
  KEY `idx_room_participant` (`participant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `chat_messages` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `room_id` BIGINT NOT NULL,
  `kind` ENUM('user','system','applyMessage','image') NOT NULL DEFAULT 'user',
  `content` TEXT NOT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `read_at` TIMESTAMP NULL DEFAULT NULL,
  `from_user_id` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_msg_room_id` (`room_id`, `id`),
  KEY `idx_msg_room_from_id` (`room_id`, `from_user_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `chat_reads` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `room_id` BIGINT NOT NULL,
  `last_read_message_id` BIGINT DEFAULT 0,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_room_unique` (`user_id`, `room_id`),
  KEY `idx_reads_room` (`room_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 4.5 任務狀態日誌
```sql
CREATE TABLE `task_status_logs` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `task_id` VARCHAR(36) NOT NULL,
  `from_status_id` INT DEFAULT NULL,
  `to_status_id` INT NOT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_task_status_time` (`task_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 4.6 評分（新）
```sql
CREATE TABLE `task_ratings` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `task_id` VARCHAR(36) NOT NULL,
  `rater_id` BIGINT UNSIGNED NOT NULL,
  `tasker_id` BIGINT UNSIGNED NOT NULL,
  `rating` TINYINT NOT NULL,
  `comment` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_task_rater_tasker` (`task_id`, `rater_id`, `tasker_id`),
  KEY `idx_task` (`task_id`),
  KEY `idx_rater` (`rater_id`),
  KEY `idx_tasker` (`tasker_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 4.7 點數 / 推薦碼（沿用現況）
> 與現況一致（如需移轉可貼現有 DDL），此處略。

---

## 5) 外鍵建議（可選，但建議在新環境強化）
> 生產環境若擔心歷史髒資料導致 FK 失敗，可先以 **應用層與定時清理** 保護，之後逐步補上 FK。

- `tasks.creator_id` → `users(id)`
- `task_applications.task_id` → `tasks(id)`；`task_applications.user_id` → `users(id)`
- `chat_rooms.task_id` → `tasks(id)`；`chat_rooms.creator_id/participant_id` → `users(id)`
- `chat_messages.room_id` → `chat_rooms(id)`；`chat_messages.from_user_id` → `users(id)`
- `chat_reads.room_id` → `chat_rooms(id)`；`chat_reads.user_id` → `users(id)`
- `task_ratings.tasker_id` / `rater_id` → `users(id)`；`task_ratings.task_id` → `tasks(id)`

---

## 6) 索引策略（與查詢對齊）
- 取房最新訊息 / 分頁：`chat_messages(room_id, id)`
- 計未讀（對方訊息 + 分界）：`chat_messages(room_id, from_user_id, id)` + `chat_reads(user_id, room_id)`
- 查我的所有房：`chat_rooms(creator_id)`、`chat_rooms(participant_id)`、`chat_rooms(task_id)`
- 倒數查詢：`task_status_logs(task_id, created_at)`

---

## 7) 遷移清單（按順序執行）

1. **Applications 標準化**
   - 修改 `task_applications.status` Enum → `('applied','accepted','rejected')`
   - 新增 `accepted_flag` 產生欄位 + 唯一鍵 `(task_id, accepted_flag)`
   - 寫入層：確保「接受某人」時同一交易中自動拒絕其他人（應用層或 DB 觸發器）

2. **新增 `task_status_logs`**（歷史補寫：可由現有任務狀態變更紀錄回填）

3. **擴充 `chat_messages.kind`** → 加入 `'image'`

4. **導入 `task_ratings`**（若保留 `reviews`：
   - 新寫入走 `task_ratings`
   - 舊資料可選擇回填 `tasker_id`（依 accepted applicant 推斷）

5. **索引補齊**（見 §6）

---

## 8) 資料品質與一致性守則

- **未讀計算**：一律以 `chat_reads.last_read_message_id` 為分界；不逐則寫回。
- **角色映射視角**：後端回傳 `mapped_status` + `raw_task_status` + `application_status`；前端不自行推導。
- **單一受雇者**：違反唯一鍵 → 回 `409`，應用層顯示友善訊息。
- **倒數轉態**：由 worker/cron 負責，**冪等**（重試不會重覆轉點）。

---

## 9) 版本維運
- **備份**：每日
- **慢查詢**：啟用日誌並定期調優索引
- **資料清理**：cache/logs 定期清理
- **Schema 版本標記**：以 migration id / release tag 標註

---

> 本文件與 `chat_module_spec.md` 相互對應。當兩份文件衝突時，以 **To‑Be**（本文件 §2 / §4 / §7）為最終準則。
