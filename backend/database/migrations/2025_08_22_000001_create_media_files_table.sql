-- 媒體檔案表
-- 用於存儲上傳的圖片、文件等媒體檔案資訊

CREATE TABLE IF NOT EXISTS `media_files` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL COMMENT '上傳用戶ID',
  `context` ENUM('chat', 'dispute', 'avatar', 'verification', 'document') NOT NULL COMMENT '使用情境',
  `related_id` VARCHAR(36) NULL COMMENT '關聯ID (聊天室ID、申訴ID等)',
  `original_name` VARCHAR(255) NOT NULL COMMENT '原始檔案名稱',
  `file_name` VARCHAR(255) NOT NULL COMMENT '儲存檔案名稱',
  `file_path` VARCHAR(500) NOT NULL COMMENT '檔案路徑',
  `file_size` INT UNSIGNED NOT NULL COMMENT '檔案大小 (bytes)',
  `mime_type` VARCHAR(100) NOT NULL COMMENT 'MIME 類型',
  `compressed` TINYINT(1) DEFAULT 0 COMMENT '是否已壓縮',
  `scan_status` ENUM('pending', 'clean', 'infected', 'error') DEFAULT 'pending' COMMENT '掃毒狀態',
  `scan_result` TEXT NULL COMMENT '掃毒結果詳情',
  `access_count` INT UNSIGNED DEFAULT 0 COMMENT '訪問次數',
  `last_accessed_at` TIMESTAMP NULL COMMENT '最後訪問時間',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '創建時間',
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
  `deleted_at` TIMESTAMP NULL COMMENT '軟刪除時間',
  
  PRIMARY KEY (`id`),
  INDEX `idx_user_context` (`user_id`, `context`),
  INDEX `idx_context_related` (`context`, `related_id`),
  INDEX `idx_file_name` (`file_name`),
  INDEX `idx_scan_status` (`scan_status`),
  INDEX `idx_created_at` (`created_at`),
  INDEX `idx_deleted_at` (`deleted_at`),
  
  CONSTRAINT `fk_media_files_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='媒體檔案表';

-- 媒體檔案訪問日誌表 (可選，用於詳細審計)
CREATE TABLE IF NOT EXISTS `media_access_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `file_id` BIGINT UNSIGNED NOT NULL COMMENT '檔案ID',
  `user_id` BIGINT UNSIGNED NULL COMMENT '訪問用戶ID (可為空，匿名訪問)',
  `ip_address` VARCHAR(45) NULL COMMENT 'IP地址',
  `user_agent` TEXT NULL COMMENT '用戶代理',
  `referer` VARCHAR(500) NULL COMMENT '來源頁面',
  `access_type` ENUM('view', 'download') DEFAULT 'view' COMMENT '訪問類型',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '訪問時間',
  
  PRIMARY KEY (`id`),
  INDEX `idx_file_id` (`file_id`),
  INDEX `idx_user_id` (`user_id`),
  INDEX `idx_ip_address` (`ip_address`),
  INDEX `idx_created_at` (`created_at`),
  
  CONSTRAINT `fk_media_access_logs_file` FOREIGN KEY (`file_id`) REFERENCES `media_files`(`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_media_access_logs_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='媒體檔案訪問日誌表';

-- 媒體檔案配額表 (用於限制用戶上傳量)
CREATE TABLE IF NOT EXISTS `media_quotas` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用戶ID',
  `context` ENUM('chat', 'dispute', 'avatar', 'verification', 'document') NOT NULL COMMENT '使用情境',
  `used_space` BIGINT UNSIGNED DEFAULT 0 COMMENT '已使用空間 (bytes)',
  `file_count` INT UNSIGNED DEFAULT 0 COMMENT '檔案數量',
  `quota_limit` BIGINT UNSIGNED DEFAULT 104857600 COMMENT '配額限制 (bytes, 預設100MB)',
  `file_limit` INT UNSIGNED DEFAULT 1000 COMMENT '檔案數量限制',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '創建時間',
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_context` (`user_id`, `context`),
  INDEX `idx_used_space` (`used_space`),
  INDEX `idx_file_count` (`file_count`),
  
  CONSTRAINT `fk_media_quotas_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='媒體檔案配額表';

-- 插入預設配額設定
INSERT IGNORE INTO `media_quotas` (`user_id`, `context`, `quota_limit`, `file_limit`)
SELECT 
    u.id,
    'chat' as context,
    104857600 as quota_limit,  -- 100MB
    500 as file_limit
FROM `users` u
WHERE u.id NOT IN (SELECT user_id FROM `media_quotas` WHERE context = 'chat');

INSERT IGNORE INTO `media_quotas` (`user_id`, `context`, `quota_limit`, `file_limit`)
SELECT 
    u.id,
    'avatar' as context,
    5242880 as quota_limit,    -- 5MB
    10 as file_limit
FROM `users` u
WHERE u.id NOT IN (SELECT user_id FROM `media_quotas` WHERE context = 'avatar');

-- 觸發器：更新配額使用量
DELIMITER //

CREATE TRIGGER `tr_media_files_insert_quota` 
AFTER INSERT ON `media_files`
FOR EACH ROW
BEGIN
    INSERT INTO `media_quotas` (`user_id`, `context`, `used_space`, `file_count`)
    VALUES (NEW.user_id, NEW.context, NEW.file_size, 1)
    ON DUPLICATE KEY UPDATE
        `used_space` = `used_space` + NEW.file_size,
        `file_count` = `file_count` + 1,
        `updated_at` = CURRENT_TIMESTAMP;
END//

CREATE TRIGGER `tr_media_files_delete_quota`
AFTER UPDATE ON `media_files`
FOR EACH ROW
BEGIN
    -- 當檔案被軟刪除時更新配額
    IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
        UPDATE `media_quotas` 
        SET `used_space` = GREATEST(0, `used_space` - OLD.file_size),
            `file_count` = GREATEST(0, `file_count` - 1),
            `updated_at` = CURRENT_TIMESTAMP
        WHERE `user_id` = OLD.user_id AND `context` = OLD.context;
    END IF;
    
    -- 當檔案被恢復時更新配額
    IF OLD.deleted_at IS NOT NULL AND NEW.deleted_at IS NULL THEN
        UPDATE `media_quotas` 
        SET `used_space` = `used_space` + NEW.file_size,
            `file_count` = `file_count` + 1,
            `updated_at` = CURRENT_TIMESTAMP
        WHERE `user_id` = NEW.user_id AND `context` = NEW.context;
    END IF;
END//

DELIMITER ;

-- 建立索引以提升查詢效能
CREATE INDEX `idx_media_files_context_created` ON `media_files` (`context`, `created_at`);
CREATE INDEX `idx_media_files_user_created` ON `media_files` (`user_id`, `created_at`);
CREATE INDEX `idx_media_files_size` ON `media_files` (`file_size`);

-- 建立視圖：用戶媒體統計
CREATE OR REPLACE VIEW `v_user_media_stats` AS
SELECT 
    u.id as user_id,
    u.name,
    u.email,
    mq.context,
    mq.used_space,
    mq.file_count,
    mq.quota_limit,
    mq.file_limit,
    ROUND((mq.used_space / mq.quota_limit) * 100, 2) as space_usage_percent,
    ROUND((mq.file_count / mq.file_limit) * 100, 2) as file_usage_percent,
    mq.updated_at as last_updated
FROM `users` u
LEFT JOIN `media_quotas` mq ON u.id = mq.user_id
ORDER BY u.id, mq.context;
