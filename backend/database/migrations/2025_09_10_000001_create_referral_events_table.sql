-- 創建推薦事件記錄表
CREATE TABLE IF NOT EXISTS referral_events (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    referrer_id BIGINT UNSIGNED NOT NULL COMMENT '推薦人ID',
    referee_id BIGINT UNSIGNED NOT NULL COMMENT '被推薦人ID',
    referral_code VARCHAR(20) NOT NULL COMMENT '使用的推薦碼',
    status ENUM('pending', 'completed', 'cancelled') DEFAULT 'pending' COMMENT '狀態：待審核、已完成、已取消',
    reward_points INT DEFAULT 500 COMMENT '獎勵點數',
    completed_at TIMESTAMP NULL COMMENT '完成時間',
    admin_id BIGINT UNSIGNED NULL COMMENT '審核管理員ID',
    notes TEXT NULL COMMENT '備註',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- 索引
    INDEX idx_referrer_id (referrer_id),
    INDEX idx_referee_id (referee_id),
    INDEX idx_referral_code (referral_code),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at),
    
    -- 外鍵約束
    CONSTRAINT fk_referral_events_referrer FOREIGN KEY (referrer_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_referral_events_referee FOREIGN KEY (referee_id) REFERENCES users(id) ON DELETE CASCADE,
    
    -- 唯一約束：每個被推薦人只能有一筆推薦記錄
    UNIQUE KEY uq_referee_id (referee_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='推薦事件記錄表';
