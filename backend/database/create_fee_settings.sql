-- 創建任務完成手續費設定表
CREATE TABLE IF NOT EXISTS `task_completion_points_fee_settings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `rate` decimal(5,4) NOT NULL DEFAULT '0.0000' COMMENT '手續費率 (0.0000 = 0%, 0.0500 = 5%)',
  `is_active` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否啟用',
  `description` text COMMENT '設定說明',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_is_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='任務完成手續費設定';

-- 插入預設的手續費設定（5% 手續費）
INSERT INTO `task_completion_points_fee_settings` (
  `rate`, 
  `is_active`, 
  `description`
) VALUES (
  0.0500,
  1,
  '任務完成手續費 5%'
) ON DUPLICATE KEY UPDATE 
  `updated_at` = CURRENT_TIMESTAMP;
