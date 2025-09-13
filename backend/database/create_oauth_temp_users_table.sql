-- 創建 oauth_temp_users 表
-- 用於存儲 OAuth 登入的臨時用戶資料

CREATE TABLE IF NOT EXISTS `oauth_temp_users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `provider` varchar(50) NOT NULL COMMENT 'OAuth 提供商 (google, facebook, apple)',
  `provider_user_id` varchar(255) NOT NULL COMMENT 'OAuth 提供商用戶 ID',
  `email` varchar(255) DEFAULT NULL COMMENT '用戶郵箱',
  `name` varchar(255) DEFAULT NULL COMMENT '用戶姓名',
  `avatar_url` varchar(500) DEFAULT NULL COMMENT '頭像 URL',
  `raw_data` text DEFAULT NULL COMMENT 'OAuth 原始資料 (JSON)',
  `token` varchar(255) NOT NULL COMMENT '臨時 token',
  `expired_at` datetime NOT NULL COMMENT '過期時間',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '創建時間',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_provider_user` (`provider`, `provider_user_id`),
  UNIQUE KEY `unique_token` (`token`),
  KEY `idx_expired_at` (`expired_at`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='OAuth 臨時用戶表';
