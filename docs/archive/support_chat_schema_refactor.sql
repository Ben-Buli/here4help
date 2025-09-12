-- 客服聊天室資料表結構調整
-- 移除不需要的欄位，統一命名規範

-- 1. 移除 support_chat_rooms 中不需要的欄位
ALTER TABLE `support_chat_rooms` 
DROP COLUMN `task_id`,
DROP COLUMN `dispute_id`;

-- 2. 統一欄位命名：creator_id -> user_id, participant_id -> admin_id
ALTER TABLE `support_chat_rooms` 
CHANGE COLUMN `creator_id` `user_id` bigint UNSIGNED NOT NULL COMMENT '客戶 ID',
CHANGE COLUMN `participant_id` `admin_id` int DEFAULT NULL COMMENT '客服 ID';

-- 3. 簡化 type 欄位，只支援 support
ALTER TABLE `support_chat_rooms` 
MODIFY COLUMN `type` enum('support') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'support';

-- 4. 移除不需要的索引
ALTER TABLE `support_chat_rooms` 
DROP INDEX `uniq_support_creator_participant`,
DROP INDEX `idx_support_room_dispute`;

-- 5. 更新索引名稱和內容
ALTER TABLE `support_chat_rooms` 
DROP INDEX `idx_support_room_creator`,
DROP INDEX `idx_support_room_participant`;

ALTER TABLE `support_chat_rooms` 
ADD KEY `idx_support_room_user` (`user_id`),
ADD KEY `idx_support_room_admin` (`admin_id`);

-- 6. 移除不需要的外鍵約束
ALTER TABLE `support_chat_rooms` 
DROP FOREIGN KEY `fk_support_room_dispute`,
DROP FOREIGN KEY `fk_support_room_task`;

-- 7. 更新外鍵約束名稱
ALTER TABLE `support_chat_rooms` 
DROP FOREIGN KEY `fk_support_room_creator`,
DROP FOREIGN KEY `fk_support_room_participant`;

ALTER TABLE `support_chat_rooms` 
ADD CONSTRAINT `fk_support_room_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
ADD CONSTRAINT `fk_support_room_admin` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL;

-- 8. 更新 support_chat_reads 的 user_id 欄位註解
ALTER TABLE `support_chat_reads` 
MODIFY COLUMN `user_id` bigint UNSIGNED NOT NULL COMMENT '用戶 ID (可能是客戶或管理員)';

-- 9. 新增唯一約束：每個用戶只能有一個進行中的客服聊天室
ALTER TABLE `support_chat_rooms` 
ADD UNIQUE KEY `uq_support_user_active` (`user_id`, `type`) COMMENT '每個用戶只能有一個進行中的客服聊天室';
