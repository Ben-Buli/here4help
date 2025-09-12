-- 調整後的 support_chat_rooms 表結構
CREATE TABLE `support_chat_rooms` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint UNSIGNED NOT NULL COMMENT '客戶 ID',
  `admin_id` int DEFAULT NULL COMMENT '客服 ID (管理員接手後填入)',
  `type` enum('support') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'support',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_support_user_active` (`user_id`, `type`) COMMENT '每個用戶只能有一個進行中的客服聊天室',
  KEY `idx_support_room_user` (`user_id`),
  KEY `idx_support_room_admin` (`admin_id`),
  CONSTRAINT `fk_support_room_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_support_room_admin` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
