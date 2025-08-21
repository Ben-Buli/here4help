-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- 主機： localhost:8889
-- 產生時間： 2025 年 08 月 21 日 16:54
-- 伺服器版本： 8.0.40
-- PHP 版本： 8.3.14

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";

--
-- 資料庫： `hero4helpdemofhs_hero4help`
--

-- --------------------------------------------------------

--
-- 資料表結構 `admins`
--

CREATE TABLE `admins` (
  `id` int NOT NULL,
  `username` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `full_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role_id` bigint UNSIGNED DEFAULT NULL,
  `status` enum('active','reset','inactive','suspended') COLLATE utf8mb4_unicode_ci DEFAULT 'active',
  `last_login` timestamp NULL DEFAULT NULL,
  `login_attempts` int DEFAULT '0',
  `locked_until` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `admin_activity_logs`
--

CREATE TABLE `admin_activity_logs` (
  `id` int NOT NULL,
  `admin_id` int NOT NULL,
  `action` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `table_name` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `record_id` int DEFAULT NULL,
  `old_data` json DEFAULT NULL,
  `new_data` json DEFAULT NULL,
  `ip_address` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_agent` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `admin_login_logs`
--

CREATE TABLE `admin_login_logs` (
  `id` int NOT NULL,
  `admin_id` int NOT NULL,
  `login_time` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `logout_time` timestamp NULL DEFAULT NULL,
  `ip_address` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_agent` text COLLATE utf8mb4_unicode_ci,
  `status` enum('success','failed','locked') COLLATE utf8mb4_unicode_ci DEFAULT 'success'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `admin_roles`
--

CREATE TABLE `admin_roles` (
  `id` bigint UNSIGNED NOT NULL,
  `name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `admin_role_permissions`
--

CREATE TABLE `admin_role_permissions` (
  `id` bigint UNSIGNED NOT NULL,
  `role_id` bigint UNSIGNED NOT NULL,
  `permission_key` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `permission_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `application_questions`
--

CREATE TABLE `application_questions` (
  `id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `task_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `application_question` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `applier_reply` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `application_questions_backup_20250111`
--

CREATE TABLE `application_questions_backup_20250111` (
  `id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `task_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `application_question` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `applier_reply` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `application_questions_backup_fill_20250111`
--

CREATE TABLE `application_questions_backup_fill_20250111` (
  `id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `task_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `application_question` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `applier_reply` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `application_questions_backup_seed_20250111`
--

CREATE TABLE `application_questions_backup_seed_20250111` (
  `id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `task_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `application_question` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `applier_reply` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `cache`
--

CREATE TABLE `cache` (
  `key` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `value` mediumtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `expiration` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `cache_locks`
--

CREATE TABLE `cache_locks` (
  `key` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `owner` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `expiration` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `chat_messages`
--

CREATE TABLE `chat_messages` (
  `id` bigint NOT NULL,
  `room_id` bigint NOT NULL,
  `kind` enum('text','image','file','system') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'text',
  `content` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `media_url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mime_type` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `from_user_id` bigint UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `chat_reads`
--

CREATE TABLE `chat_reads` (
  `id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `room_id` bigint NOT NULL,
  `last_read_message_id` bigint UNSIGNED NOT NULL DEFAULT '0',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `chat_reads_backup_20250816`
--

CREATE TABLE `chat_reads_backup_20250816` (
  `user_id` bigint NOT NULL,
  `room_id` bigint NOT NULL,
  `last_read_message_id` bigint UNSIGNED NOT NULL DEFAULT '0',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `chat_reads_duplicates_backup`
--

CREATE TABLE `chat_reads_duplicates_backup` (
  `id` bigint NOT NULL DEFAULT '0',
  `user_id` bigint NOT NULL,
  `room_id` bigint NOT NULL,
  `last_read_message_id` bigint UNSIGNED NOT NULL DEFAULT '0',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `chat_rooms`
--

CREATE TABLE `chat_rooms` (
  `id` bigint NOT NULL,
  `task_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `dispute_id` bigint UNSIGNED DEFAULT NULL,
  `creator_id` bigint UNSIGNED NOT NULL,
  `participant_id` bigint UNSIGNED NOT NULL,
  `type` enum('application','task','support','dispute') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'task',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `chat_rooms_backup_20250111`
--

CREATE TABLE `chat_rooms_backup_20250111` (
  `id` bigint NOT NULL DEFAULT '0',
  `task_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `creator_id` bigint UNSIGNED NOT NULL,
  `participant_id` bigint UNSIGNED NOT NULL,
  `type` enum('application','task') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'application',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `discarded_support_chat_messages`
--

CREATE TABLE `discarded_support_chat_messages` (
  `id` int NOT NULL,
  `chat_room_id` int NOT NULL,
  `sender_type` enum('user','admin') COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '發送者類型',
  `sender_id` bigint UNSIGNED NOT NULL COMMENT '發送者ID',
  `message` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `is_read` tinyint(1) DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `discarded_support_chat_rooms`
--

CREATE TABLE `discarded_support_chat_rooms` (
  `id` int NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `subject` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '聊天主題',
  `status` enum('open','closed','pending') COLLATE utf8mb4_unicode_ci DEFAULT 'open',
  `priority` enum('low','medium','high','urgent') COLLATE utf8mb4_unicode_ci DEFAULT 'medium',
  `assigned_admin_id` int DEFAULT NULL COMMENT '指派的管理員ID',
  `unread_count` int DEFAULT '0' COMMENT '未讀訊息數',
  `last_message_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `dispute_chats`
--

CREATE TABLE `dispute_chats` (
  `id` bigint UNSIGNED NOT NULL,
  `task_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `admin_id` int DEFAULT NULL,
  `status` enum('open','closed','pending') COLLATE utf8mb4_unicode_ci DEFAULT 'open',
  `unread_count` int DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `dispute_status_logs`
--

CREATE TABLE `dispute_status_logs` (
  `id` bigint UNSIGNED NOT NULL,
  `dispute_id` bigint UNSIGNED NOT NULL,
  `status` enum('open','in_review','resolved','rejected') COLLATE utf8mb4_unicode_ci NOT NULL,
  `changed_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `changed_by` bigint UNSIGNED DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `email_verification_tokens`
--

CREATE TABLE `email_verification_tokens` (
  `id` bigint UNSIGNED NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `token` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '驗證 token，64 字元 hex 字串',
  `type` enum('email_verification','password_reset') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'email_verification' COMMENT 'token 類型',
  `expires_at` timestamp NOT NULL COMMENT '過期時間',
  `used` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否已使用',
  `used_at` timestamp NULL DEFAULT NULL COMMENT '使用時間',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `failed_jobs`
--

CREATE TABLE `failed_jobs` (
  `id` bigint UNSIGNED NOT NULL,
  `uuid` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `connection` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `queue` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `payload` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `exception` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `failed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `jobs`
--

CREATE TABLE `jobs` (
  `id` bigint UNSIGNED NOT NULL,
  `queue` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `payload` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `attempts` tinyint UNSIGNED NOT NULL,
  `reserved_at` int UNSIGNED DEFAULT NULL,
  `available_at` int UNSIGNED NOT NULL,
  `created_at` int UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `job_batches`
--

CREATE TABLE `job_batches` (
  `id` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `total_jobs` int NOT NULL,
  `pending_jobs` int NOT NULL,
  `failed_jobs` int NOT NULL,
  `failed_job_ids` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `options` mediumtext COLLATE utf8mb4_unicode_ci,
  `cancelled_at` int DEFAULT NULL,
  `created_at` int NOT NULL,
  `finished_at` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `languages`
--

CREATE TABLE `languages` (
  `id` int NOT NULL,
  `code` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '語言代碼',
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '英文名稱',
  `native` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '原生語言名稱',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `migrations`
--

CREATE TABLE `migrations` (
  `id` int UNSIGNED NOT NULL,
  `migration` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `batch` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `oauth_temp_users`
--

CREATE TABLE `oauth_temp_users` (
  `id` bigint UNSIGNED NOT NULL,
  `provider` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '第三方登入提供者：google, facebook, apple',
  `provider_user_id` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '第三方平台的用戶ID',
  `email` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '第三方平台提供的email',
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '第三方平台提供的姓名',
  `avatar_url` text COLLATE utf8mb4_unicode_ci COMMENT '第三方平台提供的頭像URL',
  `raw_data` json DEFAULT NULL COMMENT '完整第三方回傳的原始資料',
  `token` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '臨時登入憑證，用於前端帶到 /signup 頁面取資料',
  `expired_at` datetime NOT NULL COMMENT '臨時資料過期時間',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `orders`
--

CREATE TABLE `orders` (
  `id` int NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `order_number` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `order_type` enum('task_creation','premium_upgrade','other') COLLATE utf8mb4_unicode_ci DEFAULT 'other',
  `amount` decimal(10,2) NOT NULL,
  `currency` varchar(3) COLLATE utf8mb4_unicode_ci DEFAULT 'TWD',
  `status` enum('pending','paid','cancelled','refunded') COLLATE utf8mb4_unicode_ci DEFAULT 'pending',
  `payment_method` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `payment_status` enum('pending','completed','failed') COLLATE utf8mb4_unicode_ci DEFAULT 'pending',
  `description` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `order_items`
--

CREATE TABLE `order_items` (
  `id` int NOT NULL,
  `order_id` int NOT NULL,
  `item_type` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `item_id` int DEFAULT NULL,
  `item_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `quantity` int DEFAULT '1',
  `unit_price` decimal(10,2) NOT NULL,
  `total_price` decimal(10,2) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `point_deposit_requests`
--

CREATE TABLE `point_deposit_requests` (
  `id` int NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `added_value` int NOT NULL COMMENT '儲值點數',
  `status` enum('pending','approved','rejected') COLLATE utf8mb4_unicode_ci DEFAULT 'pending',
  `reply_description` text COLLATE utf8mb4_unicode_ci COMMENT '審核回覆說明',
  `approver_id` int DEFAULT NULL COMMENT '審核管理員ID',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `referral_codes`
--

CREATE TABLE `referral_codes` (
  `id` int NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `referral_code` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL,
  `is_used` tinyint(1) DEFAULT '0',
  `used_by_user_id` bigint UNSIGNED DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `referral_events`
--

CREATE TABLE `referral_events` (
  `id` bigint UNSIGNED NOT NULL,
  `referrer_id` bigint UNSIGNED NOT NULL,
  `referee_id` bigint UNSIGNED DEFAULT NULL,
  `referral_code` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` enum('pending','completed','expired') COLLATE utf8mb4_unicode_ci DEFAULT 'pending',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `completed_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `service_chats`
--

CREATE TABLE `service_chats` (
  `id` bigint UNSIGNED NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `admin_id` int DEFAULT NULL,
  `status` enum('open','closed','pending') COLLATE utf8mb4_unicode_ci DEFAULT 'open',
  `unread_count` int DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `student_verifications`
--

CREATE TABLE `student_verifications` (
  `id` bigint UNSIGNED NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `school_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `student_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `student_id` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `student_id_image_path` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `verification_status` enum('pending','approved','rejected') COLLATE utf8mb4_unicode_ci DEFAULT 'pending',
  `verification_notes` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `support_events`
--

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

-- --------------------------------------------------------

--
-- 資料表結構 `support_event_logs`
--

CREATE TABLE `support_event_logs` (
  `id` bigint NOT NULL,
  `event_id` bigint NOT NULL,
  `admin_id` int DEFAULT NULL COMMENT '操作人',
  `old_status` enum('open','in_progress','resolved','closed_by_customer') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `new_status` enum('open','in_progress','resolved','closed_by_customer') COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `tasks`
--

CREATE TABLE `tasks` (
  `id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `creator_id` bigint UNSIGNED NOT NULL,
  `participant_id` bigint UNSIGNED DEFAULT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `reward_point` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `location` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `task_date` date NOT NULL,
  `start_datetime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `end_datetime` datetime NOT NULL DEFAULT ((now() + interval 1 hour)),
  `status_id` int DEFAULT '1',
  `creator_confirmed` tinyint(1) DEFAULT '0',
  `acceptor_confirmed` tinyint(1) DEFAULT '0',
  `cancel_reason` text COLLATE utf8mb4_unicode_ci,
  `fail_reason` text COLLATE utf8mb4_unicode_ci,
  `language_requirement` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `hashtags` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- 觸發器 `tasks`
--
DELIMITER $$
CREATE TRIGGER `tasks_before_insert_uuid` BEFORE INSERT ON `tasks` FOR EACH ROW BEGIN
  IF NEW.id IS NULL OR NEW.id = '' THEN
    SET NEW.id = UUID();
  END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `tasks_backup`
--

CREATE TABLE `tasks_backup` (
  `id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `creator_id` bigint UNSIGNED DEFAULT NULL,
  `acceptor_id` varchar(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `reward_point` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `location` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `task_date` date NOT NULL,
  `status_id` int DEFAULT '1',
  `creator_confirmed` tinyint(1) DEFAULT '0',
  `acceptor_confirmed` tinyint(1) DEFAULT '0',
  `cancel_reason` text COLLATE utf8mb4_unicode_ci,
  `fail_reason` text COLLATE utf8mb4_unicode_ci,
  `language_requirement` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `hashtags` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `tasks_backup_20250809`
--

CREATE TABLE `tasks_backup_20250809` (
  `id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `creator_id` bigint UNSIGNED DEFAULT NULL,
  `acceptor_id` bigint UNSIGNED DEFAULT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `reward_point` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `location` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `task_date` date NOT NULL,
  `status_id` int DEFAULT '1',
  `creator_confirmed` tinyint(1) DEFAULT '0',
  `acceptor_confirmed` tinyint(1) DEFAULT '0',
  `cancel_reason` text COLLATE utf8mb4_unicode_ci,
  `fail_reason` text COLLATE utf8mb4_unicode_ci,
  `language_requirement` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `hashtags` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `task_activity_logs_legacy_20250820`
--

CREATE TABLE `task_activity_logs_legacy_20250820` (
  `id` int NOT NULL,
  `task_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `action` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '操作類型：created, status_changed, assigned, completed等',
  `old_status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `new_status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `admin_id` int DEFAULT NULL COMMENT '操作管理員ID（如果是管理員操作）',
  `user_id` bigint UNSIGNED DEFAULT NULL COMMENT '操作用戶ID（如果是用戶操作）',
  `description` text COLLATE utf8mb4_unicode_ci COMMENT '操作描述',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `task_applications`
--

CREATE TABLE `task_applications` (
  `id` bigint NOT NULL,
  `task_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `status` enum('applied','accepted','rejected','pending','completed','cancelled','dispute') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'applied',
  `cover_letter` text COLLATE utf8mb4_unicode_ci,
  `answers_json` json DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `accepted_flag` tinyint GENERATED ALWAYS AS ((case when (`status` = _utf8mb4'accepted') then 1 else NULL end)) STORED
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- 觸發器 `task_applications`
--
DELIMITER $$
CREATE TRIGGER `trg_app_insert_auto_reject` AFTER INSERT ON `task_applications` FOR EACH ROW BEGIN
  IF NEW.status = 'accepted' THEN
    UPDATE task_applications
       SET status = 'rejected'
     WHERE task_id = NEW.task_id
       AND id <> NEW.id
       AND status = 'applied';
  END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_app_update_auto_reject` AFTER UPDATE ON `task_applications` FOR EACH ROW BEGIN
  IF NEW.status = 'accepted' AND OLD.status <> 'accepted' THEN
    UPDATE task_applications
       SET status = 'rejected'
     WHERE task_id = NEW.task_id
       AND id <> NEW.id
       AND status = 'applied';  -- 只把「應徵中」的人改掉
  END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `task_applications_backup_20250111`
--

CREATE TABLE `task_applications_backup_20250111` (
  `id` bigint NOT NULL DEFAULT '0',
  `task_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'applied',
  `cover_letter` text COLLATE utf8mb4_unicode_ci,
  `answers_json` json DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `task_applications_backup_fill_20250111`
--

CREATE TABLE `task_applications_backup_fill_20250111` (
  `id` bigint NOT NULL DEFAULT '0',
  `task_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'applied',
  `cover_letter` text COLLATE utf8mb4_unicode_ci,
  `answers_json` json DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `task_applications_backup_seed_20250111`
--

CREATE TABLE `task_applications_backup_seed_20250111` (
  `id` bigint NOT NULL DEFAULT '0',
  `task_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'applied',
  `cover_letter` text COLLATE utf8mb4_unicode_ci,
  `answers_json` json DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `task_disputes`
--

CREATE TABLE `task_disputes` (
  `id` bigint UNSIGNED NOT NULL,
  `task_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `status` enum('open','in_review','resolved','rejected') COLLATE utf8mb4_unicode_ci DEFAULT 'open',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `resolved_at` timestamp NULL DEFAULT NULL,
  `rejected_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- 觸發器 `task_disputes`
--
DELIMITER $$
CREATE TRIGGER `trg_dispute_after_insert` AFTER INSERT ON `task_disputes` FOR EACH ROW BEGIN
  INSERT INTO dispute_status_logs (dispute_id, status, changed_at)
  VALUES (NEW.id, NEW.status, NOW());
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `task_dispute_chat_messages`
--

CREATE TABLE `task_dispute_chat_messages` (
  `id` int NOT NULL,
  `chat_room_id` int NOT NULL,
  `sender_type` enum('user','admin') COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '發送者類型',
  `sender_id` bigint UNSIGNED NOT NULL COMMENT '發送者ID',
  `message` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `is_read` tinyint(1) DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `task_dispute_chat_rooms`
--

CREATE TABLE `task_dispute_chat_rooms` (
  `id` int NOT NULL,
  `task_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `subject` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '申訴主題',
  `status` enum('open','closed','pending') COLLATE utf8mb4_unicode_ci DEFAULT 'open',
  `priority` enum('low','medium','high','urgent') COLLATE utf8mb4_unicode_ci DEFAULT 'medium',
  `assigned_admin_id` int DEFAULT NULL COMMENT '指派的管理員ID',
  `unread_count` int DEFAULT '0' COMMENT '未讀訊息數',
  `last_message_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `task_favorites`
--

CREATE TABLE `task_favorites` (
  `id` bigint UNSIGNED NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `task_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `task_logs`
--

CREATE TABLE `task_logs` (
  `id` bigint UNSIGNED NOT NULL,
  `task_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `action` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `old_status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `new_status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `admin_id` int DEFAULT NULL,
  `user_id` bigint UNSIGNED DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `task_ratings`
--

CREATE TABLE `task_ratings` (
  `id` bigint UNSIGNED NOT NULL,
  `task_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `rater_id` bigint UNSIGNED NOT NULL,
  `tasker_id` bigint UNSIGNED NOT NULL,
  `rating` tinyint UNSIGNED NOT NULL,
  `comment` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `task_reports`
--

CREATE TABLE `task_reports` (
  `id` bigint UNSIGNED NOT NULL,
  `task_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `reporter_id` bigint UNSIGNED NOT NULL,
  `reason` enum('inappropriate','spam','fake','dangerous','other') COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` enum('pending','reviewed','resolved','dismissed') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `admin_id` int DEFAULT NULL,
  `admin_notes` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `task_statuses`
--

CREATE TABLE `task_statuses` (
  `id` int NOT NULL,
  `code` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `display_name` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL,
  `progress_ratio` decimal(3,2) NOT NULL DEFAULT '0.00',
  `sort_order` int NOT NULL DEFAULT '0',
  `include_in_unread` tinyint(1) NOT NULL DEFAULT '1',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `task_status_logs_legacy_20250820`
--

CREATE TABLE `task_status_logs_legacy_20250820` (
  `id` bigint UNSIGNED NOT NULL,
  `task_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `old_status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `new_status` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `admin_id` int DEFAULT NULL,
  `reason` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `universities`
--

CREATE TABLE `universities` (
  `id` int NOT NULL,
  `zh_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '中文名稱',
  `en_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '英文名稱',
  `abbr` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '縮寫代號',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `users`
--

CREATE TABLE `users` (
  `id` bigint UNSIGNED NOT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `nickname` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '用戶email，第三方登入帳號可為NULL',
  `password` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '用戶密碼，第三方登入帳號可為NULL',
  `email_verified_at` datetime DEFAULT NULL COMMENT 'email 驗證時間',
  `payment_password` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_of_birth` date DEFAULT NULL,
  `gender` enum('Male','Female','Non-binary','Genderfluid','Agender','Bigender','Genderqueer','Two-spirit','Other','Prefer not to disclose') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Prefer not to disclose',
  `country` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `is_permanent_address` tinyint(1) DEFAULT '0',
  `primary_language` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'English',
  `school` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `phone` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `permission` int DEFAULT '0' COMMENT '0=新用戶未認證, 1=已認證用戶, 99=管理員, -1=被管理員停權, -2=被管理員軟刪除, -3=用戶自行停權, -4=用戶自行軟刪除',
  `avatar_url` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `terms_accepted_at` datetime DEFAULT NULL COMMENT '條款接受時間',
  `points` int NOT NULL DEFAULT '0',
  `status` enum('active','pending_review','rejected','banned','inactive') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'pending_review',
  `language_requirement` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `referral_code` varchar(12) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `user_blocks`
--

CREATE TABLE `user_blocks` (
  `id` bigint UNSIGNED NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `target_user_id` bigint UNSIGNED NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `user_identities`
--

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

-- --------------------------------------------------------

--
-- 資料表結構 `user_point_reviews`
--

CREATE TABLE `user_point_reviews` (
  `id` bigint UNSIGNED NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `added_value` int NOT NULL DEFAULT '0',
  `status` enum('pending','approved','rejected') COLLATE utf8mb4_unicode_ci DEFAULT 'pending',
  `reply_description` text COLLATE utf8mb4_unicode_ci,
  `approver` int DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `user_tokens`
--

CREATE TABLE `user_tokens` (
  `id` bigint UNSIGNED NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `token` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `expires_at` timestamp NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `user_verification_rejections`
--

CREATE TABLE `user_verification_rejections` (
  `id` int NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `admin_id` int NOT NULL,
  `rejection_reason` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `verification_rejections`
--

CREATE TABLE `verification_rejections` (
  `id` bigint UNSIGNED NOT NULL,
  `admin_id` int NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `reason` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 替換檢視表以便查看 `v_task_activity_logs`
-- (請參考以下實際畫面)
--
CREATE TABLE `v_task_activity_logs` (
`id` bigint unsigned
,`task_id` varchar(36)
,`action` varchar(64)
,`old_status` varchar(50)
,`new_status` varchar(50)
,`admin_id` int
,`user_id` bigint unsigned
,`description` text
,`created_at` timestamp
);

-- --------------------------------------------------------

--
-- 替換檢視表以便查看 `v_task_status_logs`
-- (請參考以下實際畫面)
--
CREATE TABLE `v_task_status_logs` (
`id` bigint unsigned
,`task_id` varchar(36)
,`old_status` varchar(50)
,`new_status` varchar(50)
,`admin_id` int
,`created_at` timestamp
);

-- --------------------------------------------------------

--
-- 檢視表結構 `v_task_activity_logs`
--
DROP TABLE IF EXISTS `v_task_activity_logs`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_task_activity_logs`  AS SELECT `task_logs`.`id` AS `id`, `task_logs`.`task_id` AS `task_id`, `task_logs`.`action` AS `action`, `task_logs`.`old_status` AS `old_status`, `task_logs`.`new_status` AS `new_status`, `task_logs`.`admin_id` AS `admin_id`, `task_logs`.`user_id` AS `user_id`, `task_logs`.`description` AS `description`, `task_logs`.`created_at` AS `created_at` FROM `task_logs` WHERE (`task_logs`.`action` <> 'status_changed') ;

-- --------------------------------------------------------

--
-- 檢視表結構 `v_task_status_logs`
--
DROP TABLE IF EXISTS `v_task_status_logs`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_task_status_logs`  AS SELECT `task_logs`.`id` AS `id`, `task_logs`.`task_id` AS `task_id`, `task_logs`.`old_status` AS `old_status`, `task_logs`.`new_status` AS `new_status`, `task_logs`.`admin_id` AS `admin_id`, `task_logs`.`created_at` AS `created_at` FROM `task_logs` WHERE (`task_logs`.`action` = 'status_changed') ;

--
-- 已傾印資料表的索引
--

--
-- 資料表索引 `admins`
--
ALTER TABLE `admins`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `username` (`username`),
  ADD UNIQUE KEY `email` (`email`),
  ADD KEY `idx_username` (`username`),
  ADD KEY `idx_email` (`email`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `fk_admin_role` (`role_id`);

--
-- 資料表索引 `admin_activity_logs`
--
ALTER TABLE `admin_activity_logs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_admin_id` (`admin_id`),
  ADD KEY `idx_action` (`action`),
  ADD KEY `idx_table_name` (`table_name`),
  ADD KEY `idx_created_at` (`created_at`);

--
-- 資料表索引 `admin_login_logs`
--
ALTER TABLE `admin_login_logs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_admin_id` (`admin_id`),
  ADD KEY `idx_login_time` (`login_time`),
  ADD KEY `idx_status` (`status`);

--
-- 資料表索引 `admin_roles`
--
ALTER TABLE `admin_roles`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `name` (`name`);

--
-- 資料表索引 `admin_role_permissions`
--
ALTER TABLE `admin_role_permissions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_role_permission` (`role_id`);

--
-- 資料表索引 `application_questions`
--
ALTER TABLE `application_questions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_task_id` (`task_id`);

--
-- 資料表索引 `cache`
--
ALTER TABLE `cache`
  ADD PRIMARY KEY (`key`);

--
-- 資料表索引 `cache_locks`
--
ALTER TABLE `cache_locks`
  ADD PRIMARY KEY (`key`);

--
-- 資料表索引 `chat_messages`
--
ALTER TABLE `chat_messages`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_msg_room` (`room_id`),
  ADD KEY `idx_room_created` (`room_id`,`created_at`),
  ADD KEY `idx_from_user` (`from_user_id`);

--
-- 資料表索引 `chat_reads`
--
ALTER TABLE `chat_reads`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_chat_reads_user_room` (`user_id`,`room_id`);

--
-- 資料表索引 `chat_rooms`
--
ALTER TABLE `chat_rooms`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_task_creator_participant` (`task_id`,`creator_id`,`participant_id`),
  ADD KEY `idx_room_creator` (`creator_id`),
  ADD KEY `idx_room_participant` (`participant_id`),
  ADD KEY `idx_room_dispute` (`dispute_id`);

--
-- 資料表索引 `discarded_support_chat_messages`
--
ALTER TABLE `discarded_support_chat_messages`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_chat_room_id` (`chat_room_id`),
  ADD KEY `idx_sender_type` (`sender_type`),
  ADD KEY `idx_sender_id` (`sender_id`),
  ADD KEY `idx_is_read` (`is_read`),
  ADD KEY `idx_created_at` (`created_at`);

--
-- 資料表索引 `discarded_support_chat_rooms`
--
ALTER TABLE `discarded_support_chat_rooms`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_assigned_admin_id` (`assigned_admin_id`),
  ADD KEY `idx_priority` (`priority`),
  ADD KEY `idx_created_at` (`created_at`);

--
-- 資料表索引 `dispute_chats`
--
ALTER TABLE `dispute_chats`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_task_id` (`task_id`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_admin_id` (`admin_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_created_at` (`created_at`);

--
-- 資料表索引 `dispute_status_logs`
--
ALTER TABLE `dispute_status_logs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_dispute_id` (`dispute_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_changed_at` (`changed_at`);

--
-- 資料表索引 `email_verification_tokens`
--
ALTER TABLE `email_verification_tokens`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_token` (`token`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_expires_at` (`expires_at`),
  ADD KEY `idx_type` (`type`),
  ADD KEY `idx_token_type_expires` (`type`,`expires_at`,`used`);

--
-- 資料表索引 `failed_jobs`
--
ALTER TABLE `failed_jobs`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `failed_jobs_uuid_unique` (`uuid`);

--
-- 資料表索引 `jobs`
--
ALTER TABLE `jobs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `jobs_queue_index` (`queue`);

--
-- 資料表索引 `job_batches`
--
ALTER TABLE `job_batches`
  ADD PRIMARY KEY (`id`);

--
-- 資料表索引 `languages`
--
ALTER TABLE `languages`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `code` (`code`),
  ADD KEY `idx_code` (`code`),
  ADD KEY `idx_name` (`name`);

--
-- 資料表索引 `migrations`
--
ALTER TABLE `migrations`
  ADD PRIMARY KEY (`id`);

--
-- 資料表索引 `oauth_temp_users`
--
ALTER TABLE `oauth_temp_users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_provider_uid` (`provider`,`provider_user_id`),
  ADD UNIQUE KEY `uq_token` (`token`);

--
-- 資料表索引 `orders`
--
ALTER TABLE `orders`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `order_number` (`order_number`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_order_number` (`order_number`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_payment_status` (`payment_status`),
  ADD KEY `idx_created_at` (`created_at`);

--
-- 資料表索引 `order_items`
--
ALTER TABLE `order_items`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_order_id` (`order_id`),
  ADD KEY `idx_item_type` (`item_type`);

--
-- 資料表索引 `point_deposit_requests`
--
ALTER TABLE `point_deposit_requests`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_approver_id` (`approver_id`),
  ADD KEY `idx_created_at` (`created_at`);

--
-- 資料表索引 `referral_codes`
--
ALTER TABLE `referral_codes`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `referral_code` (`referral_code`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_referral_code` (`referral_code`),
  ADD KEY `idx_is_used` (`is_used`),
  ADD KEY `used_by_user_id` (`used_by_user_id`);

--
-- 資料表索引 `referral_events`
--
ALTER TABLE `referral_events`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_referrer` (`referrer_id`),
  ADD KEY `fk_referee` (`referee_id`),
  ADD KEY `idx_referral_code` (`referral_code`);

--
-- 資料表索引 `service_chats`
--
ALTER TABLE `service_chats`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_admin_id` (`admin_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_created_at` (`created_at`);

--
-- 資料表索引 `student_verifications`
--
ALTER TABLE `student_verifications`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_verification_status` (`verification_status`),
  ADD KEY `idx_created_at` (`created_at`),
  ADD KEY `idx_student_verifications_status_created` (`verification_status`,`created_at`);

--
-- 資料表索引 `support_events`
--
ALTER TABLE `support_events`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_chat_room_status` (`chat_room_id`,`status`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `fk_support_events_admin` (`admin_id`);

--
-- 資料表索引 `support_event_logs`
--
ALTER TABLE `support_event_logs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_event_id` (`event_id`),
  ADD KEY `fk_event_logs_admin` (`admin_id`);

--
-- 資料表索引 `tasks`
--
ALTER TABLE `tasks`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_acceptor_id` (`participant_id`),
  ADD KEY `idx_task_date` (`task_date`),
  ADD KEY `idx_location` (`location`),
  ADD KEY `idx_language_requirement` (`language_requirement`),
  ADD KEY `idx_tasks_status_created` (`created_at`),
  ADD KEY `idx_tasks_status_id` (`status_id`),
  ADD KEY `idx_tasks_creator_id` (`creator_id`),
  ADD KEY `idx_tasks_acceptor_id` (`participant_id`);

--
-- 資料表索引 `tasks_backup`
--
ALTER TABLE `tasks_backup`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_acceptor_id` (`acceptor_id`),
  ADD KEY `idx_task_date` (`task_date`),
  ADD KEY `idx_location` (`location`),
  ADD KEY `idx_language_requirement` (`language_requirement`),
  ADD KEY `idx_tasks_status_created` (`created_at`),
  ADD KEY `idx_tasks_status_id` (`status_id`),
  ADD KEY `idx_tasks_creator_id` (`creator_id`);

--
-- 資料表索引 `task_activity_logs_legacy_20250820`
--
ALTER TABLE `task_activity_logs_legacy_20250820`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_task_id` (`task_id`),
  ADD KEY `idx_action` (`action`),
  ADD KEY `idx_admin_id` (`admin_id`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_created_at` (`created_at`);

--
-- 資料表索引 `task_applications`
--
ALTER TABLE `task_applications`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_task_user` (`task_id`,`user_id`),
  ADD UNIQUE KEY `uk_task_one_accept` (`task_id`,`accepted_flag`),
  ADD KEY `idx_app_user` (`user_id`),
  ADD KEY `idx_app_task` (`task_id`);

--
-- 資料表索引 `task_disputes`
--
ALTER TABLE `task_disputes`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_task_id` (`task_id`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_status` (`status`);

--
-- 資料表索引 `task_dispute_chat_messages`
--
ALTER TABLE `task_dispute_chat_messages`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_chat_room_id` (`chat_room_id`),
  ADD KEY `idx_sender_type` (`sender_type`),
  ADD KEY `idx_sender_id` (`sender_id`),
  ADD KEY `idx_is_read` (`is_read`),
  ADD KEY `idx_created_at` (`created_at`);

--
-- 資料表索引 `task_dispute_chat_rooms`
--
ALTER TABLE `task_dispute_chat_rooms`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_task_id` (`task_id`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_assigned_admin_id` (`assigned_admin_id`),
  ADD KEY `idx_priority` (`priority`),
  ADD KEY `idx_created_at` (`created_at`);

--
-- 資料表索引 `task_favorites`
--
ALTER TABLE `task_favorites`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_user_task` (`user_id`,`task_id`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_task_id` (`task_id`);

--
-- 資料表索引 `task_logs`
--
ALTER TABLE `task_logs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_task_id` (`task_id`),
  ADD KEY `idx_action` (`action`),
  ADD KEY `idx_admin_id` (`admin_id`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_created_at` (`created_at`);

--
-- 資料表索引 `task_ratings`
--
ALTER TABLE `task_ratings`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uk_task_rater_tasker` (`task_id`,`rater_id`,`tasker_id`),
  ADD KEY `idx_tasker` (`tasker_id`),
  ADD KEY `idx_rater` (`rater_id`),
  ADD KEY `idx_task` (`task_id`);

--
-- 資料表索引 `task_reports`
--
ALTER TABLE `task_reports`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_task_id` (`task_id`),
  ADD KEY `idx_reporter_id` (`reporter_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `fk_task_reports_admin` (`admin_id`);

--
-- 資料表索引 `task_statuses`
--
ALTER TABLE `task_statuses`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `code` (`code`);

--
-- 資料表索引 `task_status_logs_legacy_20250820`
--
ALTER TABLE `task_status_logs_legacy_20250820`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `id` (`id`),
  ADD KEY `idx_task_id` (`task_id`),
  ADD KEY `idx_admin_id` (`admin_id`),
  ADD KEY `idx_created_at` (`created_at`);

--
-- 資料表索引 `universities`
--
ALTER TABLE `universities`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `abbr` (`abbr`),
  ADD KEY `idx_abbr` (`abbr`),
  ADD KEY `idx_zh_name` (`zh_name`),
  ADD KEY `idx_en_name` (`en_name`);

--
-- 資料表索引 `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_users_email` (`email`),
  ADD UNIQUE KEY `uq_users_referral_code_ci` (`referral_code`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_created_at` (`created_at`),
  ADD KEY `idx_users_status_created` (`status`,`created_at`),
  ADD KEY `idx_email_verified` (`email_verified_at`),
  ADD KEY `idx_terms_accepted` (`terms_accepted_at`);

--
-- 資料表索引 `user_blocks`
--
ALTER TABLE `user_blocks`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_user_target` (`user_id`,`target_user_id`);

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
-- 資料表索引 `user_point_reviews`
--
ALTER TABLE `user_point_reviews`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_approver` (`approver`),
  ADD KEY `idx_created_at` (`created_at`);

--
-- 資料表索引 `user_tokens`
--
ALTER TABLE `user_tokens`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `token` (`token`),
  ADD KEY `idx_token` (`token`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_expires_at` (`expires_at`);

--
-- 資料表索引 `user_verification_rejections`
--
ALTER TABLE `user_verification_rejections`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_admin_id` (`admin_id`),
  ADD KEY `idx_created_at` (`created_at`);

--
-- 資料表索引 `verification_rejections`
--
ALTER TABLE `verification_rejections`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_admin_id` (`admin_id`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_created_at` (`created_at`);

--
-- 在傾印的資料表使用自動遞增(AUTO_INCREMENT)
--

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `admins`
--
ALTER TABLE `admins`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `admin_activity_logs`
--
ALTER TABLE `admin_activity_logs`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `admin_login_logs`
--
ALTER TABLE `admin_login_logs`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `admin_roles`
--
ALTER TABLE `admin_roles`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `admin_role_permissions`
--
ALTER TABLE `admin_role_permissions`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `chat_messages`
--
ALTER TABLE `chat_messages`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `chat_reads`
--
ALTER TABLE `chat_reads`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `chat_rooms`
--
ALTER TABLE `chat_rooms`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `discarded_support_chat_messages`
--
ALTER TABLE `discarded_support_chat_messages`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `discarded_support_chat_rooms`
--
ALTER TABLE `discarded_support_chat_rooms`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `dispute_chats`
--
ALTER TABLE `dispute_chats`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `dispute_status_logs`
--
ALTER TABLE `dispute_status_logs`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `email_verification_tokens`
--
ALTER TABLE `email_verification_tokens`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `failed_jobs`
--
ALTER TABLE `failed_jobs`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `jobs`
--
ALTER TABLE `jobs`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `languages`
--
ALTER TABLE `languages`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `migrations`
--
ALTER TABLE `migrations`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `oauth_temp_users`
--
ALTER TABLE `oauth_temp_users`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `orders`
--
ALTER TABLE `orders`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `order_items`
--
ALTER TABLE `order_items`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `point_deposit_requests`
--
ALTER TABLE `point_deposit_requests`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `referral_codes`
--
ALTER TABLE `referral_codes`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `referral_events`
--
ALTER TABLE `referral_events`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `service_chats`
--
ALTER TABLE `service_chats`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `student_verifications`
--
ALTER TABLE `student_verifications`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `support_events`
--
ALTER TABLE `support_events`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `support_event_logs`
--
ALTER TABLE `support_event_logs`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `task_activity_logs_legacy_20250820`
--
ALTER TABLE `task_activity_logs_legacy_20250820`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `task_applications`
--
ALTER TABLE `task_applications`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `task_disputes`
--
ALTER TABLE `task_disputes`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `task_dispute_chat_messages`
--
ALTER TABLE `task_dispute_chat_messages`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `task_dispute_chat_rooms`
--
ALTER TABLE `task_dispute_chat_rooms`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `task_favorites`
--
ALTER TABLE `task_favorites`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `task_logs`
--
ALTER TABLE `task_logs`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `task_ratings`
--
ALTER TABLE `task_ratings`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `task_reports`
--
ALTER TABLE `task_reports`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `task_statuses`
--
ALTER TABLE `task_statuses`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `task_status_logs_legacy_20250820`
--
ALTER TABLE `task_status_logs_legacy_20250820`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `universities`
--
ALTER TABLE `universities`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `users`
--
ALTER TABLE `users`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `user_blocks`
--
ALTER TABLE `user_blocks`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `user_identities`
--
ALTER TABLE `user_identities`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `user_point_reviews`
--
ALTER TABLE `user_point_reviews`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `user_tokens`
--
ALTER TABLE `user_tokens`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `user_verification_rejections`
--
ALTER TABLE `user_verification_rejections`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `verification_rejections`
--
ALTER TABLE `verification_rejections`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 已傾印資料表的限制式
--

--
-- 資料表的限制式 `admins`
--
ALTER TABLE `admins`
  ADD CONSTRAINT `fk_admin_role` FOREIGN KEY (`role_id`) REFERENCES `admin_roles` (`id`) ON DELETE SET NULL;

--
-- 資料表的限制式 `admin_role_permissions`
--
ALTER TABLE `admin_role_permissions`
  ADD CONSTRAINT `fk_role_permission` FOREIGN KEY (`role_id`) REFERENCES `admin_roles` (`id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `application_questions`
--
ALTER TABLE `application_questions`
  ADD CONSTRAINT `application_questions_ibfk_1` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `chat_messages`
--
ALTER TABLE `chat_messages`
  ADD CONSTRAINT `fk_chat_messages_room` FOREIGN KEY (`room_id`) REFERENCES `chat_rooms` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_chat_messages_user` FOREIGN KEY (`from_user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_msg_room` FOREIGN KEY (`room_id`) REFERENCES `chat_rooms` (`id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `chat_rooms`
--
ALTER TABLE `chat_rooms`
  ADD CONSTRAINT `fk_room_creator` FOREIGN KEY (`creator_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_room_dispute` FOREIGN KEY (`dispute_id`) REFERENCES `task_disputes` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_room_participant` FOREIGN KEY (`participant_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_room_task` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `discarded_support_chat_messages`
--
ALTER TABLE `discarded_support_chat_messages`
  ADD CONSTRAINT `discarded_support_chat_messages_ibfk_1` FOREIGN KEY (`chat_room_id`) REFERENCES `discarded_support_chat_rooms` (`id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `discarded_support_chat_rooms`
--
ALTER TABLE `discarded_support_chat_rooms`
  ADD CONSTRAINT `discarded_support_chat_rooms_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `discarded_support_chat_rooms_ibfk_2` FOREIGN KEY (`assigned_admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL;

--
-- 資料表的限制式 `dispute_chats`
--
ALTER TABLE `dispute_chats`
  ADD CONSTRAINT `dispute_chats_ibfk_1` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `dispute_chats_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `dispute_chats_ibfk_3` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL;

--
-- 資料表的限制式 `dispute_status_logs`
--
ALTER TABLE `dispute_status_logs`
  ADD CONSTRAINT `fk_dsl_dispute` FOREIGN KEY (`dispute_id`) REFERENCES `task_disputes` (`id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `email_verification_tokens`
--
ALTER TABLE `email_verification_tokens`
  ADD CONSTRAINT `fk_email_verification_tokens_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `point_deposit_requests`
--
ALTER TABLE `point_deposit_requests`
  ADD CONSTRAINT `point_deposit_requests_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `point_deposit_requests_ibfk_2` FOREIGN KEY (`approver_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL;

--
-- 資料表的限制式 `referral_codes`
--
ALTER TABLE `referral_codes`
  ADD CONSTRAINT `referral_codes_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `referral_codes_ibfk_2` FOREIGN KEY (`used_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- 資料表的限制式 `referral_events`
--
ALTER TABLE `referral_events`
  ADD CONSTRAINT `fk_referee` FOREIGN KEY (`referee_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_referrer` FOREIGN KEY (`referrer_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `service_chats`
--
ALTER TABLE `service_chats`
  ADD CONSTRAINT `service_chats_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `service_chats_ibfk_2` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL;

--
-- 資料表的限制式 `student_verifications`
--
ALTER TABLE `student_verifications`
  ADD CONSTRAINT `student_verifications_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `support_events`
--
ALTER TABLE `support_events`
  ADD CONSTRAINT `fk_support_events_admin` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_support_events_chat_room` FOREIGN KEY (`chat_room_id`) REFERENCES `chat_rooms` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_support_events_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `support_event_logs`
--
ALTER TABLE `support_event_logs`
  ADD CONSTRAINT `fk_event_logs_admin` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_event_logs_event` FOREIGN KEY (`event_id`) REFERENCES `support_events` (`id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `tasks`
--
ALTER TABLE `tasks`
  ADD CONSTRAINT `fk_tasks_creator` FOREIGN KEY (`creator_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_tasks_participant` FOREIGN KEY (`participant_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- 資料表的限制式 `task_activity_logs_legacy_20250820`
--
ALTER TABLE `task_activity_logs_legacy_20250820`
  ADD CONSTRAINT `task_activity_logs_legacy_20250820_ibfk_1` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `task_activity_logs_legacy_20250820_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- 資料表的限制式 `task_applications`
--
ALTER TABLE `task_applications`
  ADD CONSTRAINT `fk_app_task` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_app_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `task_disputes`
--
ALTER TABLE `task_disputes`
  ADD CONSTRAINT `fk_dispute_task` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_dispute_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `task_dispute_chat_messages`
--
ALTER TABLE `task_dispute_chat_messages`
  ADD CONSTRAINT `task_dispute_chat_messages_ibfk_1` FOREIGN KEY (`chat_room_id`) REFERENCES `task_dispute_chat_rooms` (`id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `task_dispute_chat_rooms`
--
ALTER TABLE `task_dispute_chat_rooms`
  ADD CONSTRAINT `task_dispute_chat_rooms_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `task_dispute_chat_rooms_ibfk_2` FOREIGN KEY (`assigned_admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL;

--
-- 資料表的限制式 `task_favorites`
--
ALTER TABLE `task_favorites`
  ADD CONSTRAINT `fk_task_favorites_task` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`),
  ADD CONSTRAINT `fk_task_favorites_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`);

--
-- 資料表的限制式 `task_logs`
--
ALTER TABLE `task_logs`
  ADD CONSTRAINT `fk_task_logs_admin` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_task_logs_task` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_task_logs_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- 資料表的限制式 `task_ratings`
--
ALTER TABLE `task_ratings`
  ADD CONSTRAINT `fk_task_ratings_rater` FOREIGN KEY (`rater_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_task_ratings_task` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_task_ratings_tasker` FOREIGN KEY (`tasker_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

--
-- 資料表的限制式 `task_reports`
--
ALTER TABLE `task_reports`
  ADD CONSTRAINT `fk_task_reports_admin` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_task_reports_reporter` FOREIGN KEY (`reporter_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_task_reports_task` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `task_status_logs_legacy_20250820`
--
ALTER TABLE `task_status_logs_legacy_20250820`
  ADD CONSTRAINT `task_status_logs_legacy_20250820_ibfk_1` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `task_status_logs_legacy_20250820_ibfk_2` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL;

--
-- 資料表的限制式 `user_identities`
--
ALTER TABLE `user_identities`
  ADD CONSTRAINT `fk_user_identities_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `user_point_reviews`
--
ALTER TABLE `user_point_reviews`
  ADD CONSTRAINT `user_point_reviews_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `user_point_reviews_ibfk_2` FOREIGN KEY (`approver`) REFERENCES `admins` (`id`) ON DELETE SET NULL;

--
-- 資料表的限制式 `user_tokens`
--
ALTER TABLE `user_tokens`
  ADD CONSTRAINT `user_tokens_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `user_verification_rejections`
--
ALTER TABLE `user_verification_rejections`
  ADD CONSTRAINT `user_verification_rejections_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `user_verification_rejections_ibfk_2` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE CASCADE;

--
-- 資料表的限制式 `verification_rejections`
--
ALTER TABLE `verification_rejections`
  ADD CONSTRAINT `verification_rejections_ibfk_1` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `verification_rejections_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;
COMMIT;
