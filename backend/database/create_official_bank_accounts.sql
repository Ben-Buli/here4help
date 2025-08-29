-- 創建官方銀行帳戶表
CREATE TABLE IF NOT EXISTS `official_bank_accounts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `bank_name` varchar(100) NOT NULL COMMENT '銀行名稱',
  `account_number` varchar(20) NOT NULL COMMENT '帳號',
  `account_holder` varchar(100) NOT NULL COMMENT '帳戶持有人',
  `is_active` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否啟用',
  `admin_id` int(11) DEFAULT NULL COMMENT '創建者管理員ID',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_is_active` (`is_active`),
  KEY `idx_admin_id` (`admin_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='官方銀行帳戶資訊';

-- 插入預設的銀行帳戶資料（請根據實際情況修改）
INSERT INTO `official_bank_accounts` (
  `bank_name`, 
  `account_number`, 
  `account_holder`, 
  `is_active`, 
  `admin_id`
) VALUES (
  '台灣銀行',
  '1234567890123456',
  'Here4Help Platform',
  1,
  1
) ON DUPLICATE KEY UPDATE 
  `updated_at` = CURRENT_TIMESTAMP;
