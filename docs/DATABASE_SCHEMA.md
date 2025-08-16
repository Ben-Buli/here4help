# Here4Help 資料庫架構文件

## 概述
本文檔描述了 Here4Help 專案的完整資料庫架構，包含所有表格的結構、關係和用途。

## 資料庫資訊
- **資料庫名稱**: `hero4helpdemofhs_hero4help`
- **字符集**: `utf8mb4`
- **排序規則**: `utf8mb4_unicode_ci`
- **引擎**: InnoDB

## 表格架構

### 1. 管理員相關表格

#### `admins` - 管理員帳戶
```sql
CREATE TABLE `admins` (
  `id` int NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `email` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `full_name` varchar(100) NOT NULL,
  `role` enum('super_admin','admin','developer','moderator') DEFAULT 'admin',
  `status` enum('active','reset','inactive','suspended') DEFAULT 'active',
  `last_login` timestamp NULL DEFAULT NULL,
  `login_attempts` int DEFAULT '0',
  `locked_until` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
);
```

#### `admin_activity_logs` - 管理員活動日誌
```sql
CREATE TABLE `admin_activity_logs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `admin_id` int NOT NULL,
  `action` varchar(100) NOT NULL,
  `table_name` varchar(50) DEFAULT NULL,
  `record_id` int DEFAULT NULL,
  `old_data` json DEFAULT NULL,
  `new_data` json DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` text,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
);
```

#### `admin_login_logs` - 管理員登入日誌
```sql
CREATE TABLE `admin_login_logs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `admin_id` int NOT NULL,
  `login_time` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `logout_time` timestamp NULL DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` text,
  `status` enum('success','failed','locked') DEFAULT 'success',
  PRIMARY KEY (`id`)
);
```

### 2. 任務相關表格

#### `tasks` - 任務主表
```sql
CREATE TABLE `tasks` (
  `id` varchar(36) NOT NULL,
  `creator_id` bigint UNSIGNED NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` text NOT NULL,
  `location` varchar(255) NOT NULL,
  `budget_min` decimal(10,2) NOT NULL,
  `budget_max` decimal(10,2) NOT NULL,
  `start_datetime` datetime NOT NULL,
  `end_datetime` datetime NOT NULL,
  `status_id` int NOT NULL DEFAULT 1,
  `popular` tinyint(1) DEFAULT 0,
  `new` tinyint(1) DEFAULT 1,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
);
```

#### `task_statuses` - 任務狀態
```sql
CREATE TABLE `task_statuses` (
  `id` int NOT NULL AUTO_INCREMENT,
  `code` varchar(50) NOT NULL,
  `display_name` varchar(100) NOT NULL,
  `progress_ratio` decimal(3,2) DEFAULT 0.00,
  `sort_order` int DEFAULT 0,
  `include_in_unread` tinyint(1) DEFAULT 1,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
);
```

#### `task_applications` - 任務申請
```sql
CREATE TABLE `task_applications` (
  `id` varchar(36) NOT NULL,
  `task_id` varchar(36) NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `status` enum('pending','approved','rejected','completed','cancelled') DEFAULT 'pending',
  `cover_letter` text,
  `proposed_budget` decimal(10,2) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
);
```

#### `application_questions` - 申請問題
```sql
CREATE TABLE `application_questions` (
  `id` varchar(36) NOT NULL,
  `task_id` varchar(36) NOT NULL,
  `application_question` text NOT NULL,
  `applier_reply` text,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
);
```

### 3. 用戶相關表格

#### `users` - 用戶主表
```sql
CREATE TABLE `users` (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL UNIQUE,
  `password` varchar(255) NOT NULL,
  `avatar_url` varchar(500) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `student_id` varchar(50) DEFAULT NULL,
  `university` varchar(255) DEFAULT NULL,
  `major` varchar(255) DEFAULT NULL,
  `year_level` varchar(50) DEFAULT NULL,
  `status` enum('active','inactive','banned') DEFAULT 'active',
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
);
```

### 4. 聊天相關表格

#### `chat_rooms` - 聊天室
```sql
CREATE TABLE `chat_rooms` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `task_id` varchar(36) NOT NULL,
  `creator_id` bigint UNSIGNED NOT NULL,
  `participant_id` bigint UNSIGNED NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
);
```

#### `chat_messages` - 聊天訊息
```sql
CREATE TABLE `chat_messages` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `room_id` bigint NOT NULL,
  `kind` enum('user','system','applyMessage') DEFAULT 'user',
  `content` text NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `read_at` timestamp NULL DEFAULT NULL,
  `from_user_id` bigint UNSIGNED NOT NULL,
  PRIMARY KEY (`id`)
);
```

#### `chat_reads` - 聊天已讀狀態 ⚠️ 需要添加自增 ID
```sql
CREATE TABLE `chat_reads` (
  `id` bigint NOT NULL AUTO_INCREMENT, -- 新增自增 ID
  `user_id` bigint UNSIGNED NOT NULL,
  `room_id` bigint NOT NULL,
  `last_read_message_id` bigint DEFAULT 0,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_room_unique` (`user_id`, `room_id`)
);
```

### 5. 推薦碼相關表格

#### `referral_codes` - 推薦碼
```sql
CREATE TABLE `referral_codes` (
  `id` varchar(36) NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `code` varchar(20) NOT NULL UNIQUE,
  `max_uses` int DEFAULT 10,
  `used_count` int DEFAULT 0,
  `is_active` tinyint(1) DEFAULT 1,
  `expires_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
);
```

#### `referral_uses` - 推薦碼使用記錄
```sql
CREATE TABLE `referral_uses` (
  `id` varchar(36) NOT NULL,
  `referral_code_id` varchar(36) NOT NULL,
  `used_by_user_id` bigint UNSIGNED NOT NULL,
  `used_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
);
```

### 6. 點數相關表格

#### `points` - 點數記錄
```sql
CREATE TABLE `points` (
  `id` varchar(36) NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `amount` int NOT NULL,
  `type` enum('earn','spend','refund','bonus') NOT NULL,
  `description` varchar(255) NOT NULL,
  `related_task_id` varchar(36) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
);
```

#### `point_requests` - 點數充值請求
```sql
CREATE TABLE `point_requests` (
  `id` varchar(36) NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `amount` int NOT NULL,
  `payment_method` varchar(50) NOT NULL,
  `status` enum('pending','approved','rejected','completed') DEFAULT 'pending',
  `admin_notes` text,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
);
```

### 7. 評價相關表格

#### `reviews` - 評價
```sql
CREATE TABLE `reviews` (
  `id` varchar(36) NOT NULL,
  `task_id` varchar(36) NOT NULL,
  `reviewer_id` bigint UNSIGNED NOT NULL,
  `reviewee_id` bigint UNSIGNED NOT NULL,
  `rating` tinyint NOT NULL,
  `comment` text,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
);
```

### 8. 系統相關表格

#### `cache` - 快取
```sql
CREATE TABLE `cache` (
  `key` varchar(255) NOT NULL,
  `value` mediumtext NOT NULL,
  `expiration` int NOT NULL,
  PRIMARY KEY (`key`)
);
```

#### `cache_locks` - 快取鎖
```sql
CREATE TABLE `cache_locks` (
  `key` varchar(255) NOT NULL,
  `owner` varchar(255) NOT NULL,
  `expiration` int NOT NULL,
  PRIMARY KEY (`key`)
);
```

## 外鍵關係

### 主要關係
1. **tasks** → **users** (creator_id)
2. **task_applications** → **tasks** (task_id)
3. **task_applications** → **users** (user_id)
4. **application_questions** → **tasks** (task_id)
5. **chat_rooms** → **tasks** (task_id)
6. **chat_rooms** → **users** (creator_id, participant_id)
7. **chat_messages** → **chat_rooms** (room_id)
8. **chat_messages** → **users** (from_user_id)
9. **chat_reads** → **users** (user_id)
10. **chat_reads** → **chat_rooms** (room_id)
11. **referral_codes** → **users** (user_id)
12. **referral_uses** → **referral_codes** (referral_code_id)
13. **referral_uses** → **users** (used_by_user_id)
14. **points** → **users** (user_id)
15. **point_requests** → **users** (user_id)
16. **reviews** → **tasks** (task_id)
17. **reviews** → **users** (reviewer_id, reviewee_id)

## 索引策略

### 主要索引
- `users.email` - 唯一索引
- `tasks.creator_id` - 普通索引
- `tasks.status_id` - 普通索引
- `task_applications.task_id` - 普通索引
- `task_applications.user_id` - 普通索引
- `chat_rooms.task_id` - 普通索引
- `chat_messages.room_id` - 普通索引
- `chat_reads.room_id, user_id` - 複合索引
- `referral_codes.code` - 唯一索引
- `points.user_id` - 普通索引

## 資料統計

### 當前資料量（截至 2025-08-16）
- **users**: 約 10+ 筆
- **tasks**: 約 30+ 筆
- **task_applications**: 約 100+ 筆
- **chat_messages**: 約 250+ 筆
- **chat_rooms**: 約 100+ 筆
- **chat_reads**: 37 筆（已清理重複資料）

## 注意事項

### 1. chat_reads 表已修改 ✅
`chat_reads` 表已成功添加自增 ID 並清理重複資料：
- ✅ 已添加自增 ID 欄位作為主鍵
- ✅ 已清理重複的 user_id, room_id 組合
- ✅ 保留每個組合的最新記錄
- ✅ 資料一致性檢查通過

### 2. 字符集統一
所有表格使用 `utf8mb4` 字符集和 `utf8mb4_unicode_ci` 排序規則，支援完整的 Unicode 字符。

### 3. 時間戳記
所有表格都包含 `created_at` 和 `updated_at` 時間戳記，確保資料追蹤。

### 4. 軟刪除
目前沒有實作軟刪除機制，如需保留歷史資料，建議添加 `deleted_at` 欄位。

## 維護建議

1. **定期備份**: 建議每日進行資料庫備份
2. **索引優化**: 根據查詢模式定期檢視和優化索引
3. **資料清理**: 定期清理過期的快取和日誌資料
4. **效能監控**: 監控慢查詢和資料庫效能指標
