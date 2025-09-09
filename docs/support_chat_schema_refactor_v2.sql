-- 客服聊天室資料表結構調整 - 方案二：一次性調整
-- 統一使用 user_id, admin_id 欄位名稱

-- 1. 先移除外鍵約束（逐個檢查並移除）
-- 檢查並移除 fk_support_room_dispute
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
     WHERE TABLE_SCHEMA = DATABASE() 
     AND TABLE_NAME = 'support_chat_rooms' 
     AND CONSTRAINT_NAME = 'fk_support_room_dispute') > 0,
    'ALTER TABLE `support_chat_rooms` DROP FOREIGN KEY `fk_support_room_dispute`',
    'SELECT "fk_support_room_dispute does not exist" as message'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 檢查並移除 fk_support_room_task
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
     WHERE TABLE_SCHEMA = DATABASE() 
     AND TABLE_NAME = 'support_chat_rooms' 
     AND CONSTRAINT_NAME = 'fk_support_room_task') > 0,
    'ALTER TABLE `support_chat_rooms` DROP FOREIGN KEY `fk_support_room_task`',
    'SELECT "fk_support_room_task does not exist" as message'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 檢查並移除 fk_support_room_creator
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
     WHERE TABLE_SCHEMA = DATABASE() 
     AND TABLE_NAME = 'support_chat_rooms' 
     AND CONSTRAINT_NAME = 'fk_support_room_creator') > 0,
    'ALTER TABLE `support_chat_rooms` DROP FOREIGN KEY `fk_support_room_creator`',
    'SELECT "fk_support_room_creator does not exist" as message'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 檢查並移除 fk_support_room_participant
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
     WHERE TABLE_SCHEMA = DATABASE() 
     AND TABLE_NAME = 'support_chat_rooms' 
     AND CONSTRAINT_NAME = 'fk_support_room_participant') > 0,
    'ALTER TABLE `support_chat_rooms` DROP FOREIGN KEY `fk_support_room_participant`',
    'SELECT "fk_support_room_participant does not exist" as message'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 2. 移除不需要的欄位（逐個檢查並移除）
-- 檢查並移除 task_id 欄位
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() 
     AND TABLE_NAME = 'support_chat_rooms' 
     AND COLUMN_NAME = 'task_id') > 0,
    'ALTER TABLE `support_chat_rooms` DROP COLUMN `task_id`',
    'SELECT "task_id column does not exist" as message'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 檢查並移除 dispute_id 欄位
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() 
     AND TABLE_NAME = 'support_chat_rooms' 
     AND COLUMN_NAME = 'dispute_id') > 0,
    'ALTER TABLE `support_chat_rooms` DROP COLUMN `dispute_id`',
    'SELECT "dispute_id column does not exist" as message'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 3. 統一欄位命名（逐個檢查並重命名）
-- 檢查並重命名 creator_id -> user_id
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() 
     AND TABLE_NAME = 'support_chat_rooms' 
     AND COLUMN_NAME = 'creator_id') > 0,
    'ALTER TABLE `support_chat_rooms` CHANGE COLUMN `creator_id` `user_id` bigint UNSIGNED NOT NULL COMMENT ''客戶 ID''',
    'SELECT "creator_id column does not exist" as message'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 檢查並重命名 participant_id -> admin_id
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() 
     AND TABLE_NAME = 'support_chat_rooms' 
     AND COLUMN_NAME = 'participant_id') > 0,
    'ALTER TABLE `support_chat_rooms` CHANGE COLUMN `participant_id` `admin_id` int DEFAULT NULL COMMENT ''客服 ID (管理員接手後填入)''',
    'SELECT "participant_id column does not exist" as message'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 4. 簡化 type 欄位，只支援 support
ALTER TABLE `support_chat_rooms` 
MODIFY COLUMN `type` enum('support') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'support';

-- 5. 移除不需要的索引（逐個檢查並移除）
-- 檢查並移除 uniq_support_creator_participant 索引
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
     WHERE TABLE_SCHEMA = DATABASE() 
     AND TABLE_NAME = 'support_chat_rooms' 
     AND INDEX_NAME = 'uniq_support_creator_participant') > 0,
    'ALTER TABLE `support_chat_rooms` DROP INDEX `uniq_support_creator_participant`',
    'SELECT "uniq_support_creator_participant index does not exist" as message'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 檢查並移除 idx_support_room_dispute 索引
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
     WHERE TABLE_SCHEMA = DATABASE() 
     AND TABLE_NAME = 'support_chat_rooms' 
     AND INDEX_NAME = 'idx_support_room_dispute') > 0,
    'ALTER TABLE `support_chat_rooms` DROP INDEX `idx_support_room_dispute`',
    'SELECT "idx_support_room_dispute index does not exist" as message'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 檢查並移除 idx_support_room_creator 索引
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
     WHERE TABLE_SCHEMA = DATABASE() 
     AND TABLE_NAME = 'support_chat_rooms' 
     AND INDEX_NAME = 'idx_support_room_creator') > 0,
    'ALTER TABLE `support_chat_rooms` DROP INDEX `idx_support_room_creator`',
    'SELECT "idx_support_room_creator index does not exist" as message'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 檢查並移除 idx_support_room_participant 索引
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
     WHERE TABLE_SCHEMA = DATABASE() 
     AND TABLE_NAME = 'support_chat_rooms' 
     AND INDEX_NAME = 'idx_support_room_participant') > 0,
    'ALTER TABLE `support_chat_rooms` DROP INDEX `idx_support_room_participant`',
    'SELECT "idx_support_room_participant index does not exist" as message'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 6. 新增新的索引
ALTER TABLE `support_chat_rooms` 
ADD KEY `idx_support_room_user` (`user_id`),
ADD KEY `idx_support_room_admin` (`admin_id`);

-- 7. 新增新的外鍵約束
ALTER TABLE `support_chat_rooms` 
ADD CONSTRAINT `fk_support_room_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
ADD CONSTRAINT `fk_support_room_admin` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL;

-- 8. 新增唯一約束：每個用戶只能有一個進行中的客服聊天室
ALTER TABLE `support_chat_rooms` 
ADD UNIQUE KEY `uq_support_user_active` (`user_id`, `type`) COMMENT '每個用戶只能有一個進行中的客服聊天室';

-- 9. 更新 support_chat_reads 的 user_id 欄位註解
ALTER TABLE `support_chat_reads` 
MODIFY COLUMN `user_id` bigint UNSIGNED NOT NULL COMMENT '用戶 ID (可能是客戶或管理員)';
