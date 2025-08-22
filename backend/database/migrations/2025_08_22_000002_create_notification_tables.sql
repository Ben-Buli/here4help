-- 通知系統相關資料表
-- 建立日期: 2025-08-22
-- 用途: 支援推播、站內、Email 通知的完整系統

-- 通知模板表
CREATE TABLE notification_templates (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    template_key VARCHAR(100) NOT NULL COMMENT '模板識別碼',
    name VARCHAR(200) NOT NULL COMMENT '模板名稱',
    description TEXT COMMENT '模板描述',
    
    -- 通知類型支援
    supports_push BOOLEAN DEFAULT TRUE COMMENT '支援推播通知',
    supports_in_app BOOLEAN DEFAULT TRUE COMMENT '支援站內通知',
    supports_email BOOLEAN DEFAULT FALSE COMMENT '支援Email通知',
    supports_sms BOOLEAN DEFAULT FALSE COMMENT '支援簡訊通知',
    
    -- 模板內容
    title_template TEXT NOT NULL COMMENT '標題模板（支援變數替換）',
    body_template TEXT NOT NULL COMMENT '內容模板（支援變數替換）',
    email_subject_template TEXT COMMENT 'Email主旨模板',
    email_body_template TEXT COMMENT 'Email內容模板（HTML）',
    
    -- 優先級與頻率控制
    priority ENUM('low', 'normal', 'high', 'urgent') DEFAULT 'normal' COMMENT '通知優先級',
    frequency_limit INT DEFAULT 0 COMMENT '頻率限制（分鐘，0為無限制）',
    
    -- 狀態與時間
    is_active BOOLEAN DEFAULT TRUE COMMENT '是否啟用',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY uk_template_key (template_key),
    INDEX idx_active (is_active),
    INDEX idx_priority (priority)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='通知模板表';

-- 通知事件矩陣表
CREATE TABLE notification_events (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL COMMENT '事件類型（task, chat, support, admin）',
    event_action VARCHAR(50) NOT NULL COMMENT '事件動作（created, updated, completed等）',
    template_key VARCHAR(100) NOT NULL COMMENT '對應模板識別碼',
    
    -- 觸發條件
    trigger_conditions JSON COMMENT '觸發條件（JSON格式）',
    target_roles JSON COMMENT '目標角色（poster, acceptor, admin等）',
    
    -- 延遲與重試
    delay_minutes INT DEFAULT 0 COMMENT '延遲發送（分鐘）',
    max_retries INT DEFAULT 3 COMMENT '最大重試次數',
    
    -- 狀態
    is_active BOOLEAN DEFAULT TRUE COMMENT '是否啟用',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY uk_event_template (event_type, event_action, template_key),
    INDEX idx_event_type (event_type),
    INDEX idx_active (is_active),
    
    FOREIGN KEY (template_key) REFERENCES notification_templates(template_key) 
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='通知事件矩陣表';

-- 使用者通知偏好表
CREATE TABLE user_notification_preferences (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL COMMENT '使用者ID',
    
    -- 全域設定
    push_enabled BOOLEAN DEFAULT TRUE COMMENT '推播通知總開關',
    in_app_enabled BOOLEAN DEFAULT TRUE COMMENT '站內通知總開關',
    email_enabled BOOLEAN DEFAULT TRUE COMMENT 'Email通知總開關',
    sms_enabled BOOLEAN DEFAULT FALSE COMMENT '簡訊通知總開關',
    
    -- 靜音時段
    quiet_hours_start TIME COMMENT '靜音開始時間',
    quiet_hours_end TIME COMMENT '靜音結束時間',
    quiet_days JSON COMMENT '靜音日期（週一到週日）',
    
    -- 分類偏好（JSON格式儲存各事件類型的偏好）
    task_preferences JSON COMMENT '任務相關通知偏好',
    chat_preferences JSON COMMENT '聊天相關通知偏好',
    support_preferences JSON COMMENT '客服相關通知偏好',
    admin_preferences JSON COMMENT '管理相關通知偏好',
    
    -- 時間戳記
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY uk_user_preferences (user_id),
    
    FOREIGN KEY (user_id) REFERENCES users(id) 
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='使用者通知偏好表';

-- 通知佇列表
CREATE TABLE notification_queue (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL COMMENT '目標使用者ID',
    template_key VARCHAR(100) NOT NULL COMMENT '使用的模板',
    
    -- 通知類型
    notification_type ENUM('push', 'in_app', 'email', 'sms') NOT NULL COMMENT '通知類型',
    
    -- 內容
    title VARCHAR(500) NOT NULL COMMENT '通知標題',
    body TEXT NOT NULL COMMENT '通知內容',
    data JSON COMMENT '額外資料（深度連結、參數等）',
    
    -- 狀態與處理
    status ENUM('pending', 'processing', 'sent', 'failed', 'cancelled') DEFAULT 'pending' COMMENT '處理狀態',
    priority ENUM('low', 'normal', 'high', 'urgent') DEFAULT 'normal' COMMENT '優先級',
    
    -- 排程與重試
    scheduled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '預定發送時間',
    sent_at TIMESTAMP NULL COMMENT '實際發送時間',
    retry_count INT DEFAULT 0 COMMENT '重試次數',
    max_retries INT DEFAULT 3 COMMENT '最大重試次數',
    
    -- 結果
    result_code VARCHAR(50) COMMENT '發送結果代碼',
    result_message TEXT COMMENT '發送結果訊息',
    external_id VARCHAR(200) COMMENT '外部服務ID（如FCM message ID）',
    
    -- 關聯資訊
    related_type VARCHAR(50) COMMENT '關聯類型（task, chat, support等）',
    related_id BIGINT UNSIGNED COMMENT '關聯ID',
    
    -- 時間戳記
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_user_status (user_id, status),
    INDEX idx_scheduled (scheduled_at, status),
    INDEX idx_priority_status (priority, status),
    INDEX idx_related (related_type, related_id),
    INDEX idx_template (template_key),
    
    FOREIGN KEY (user_id) REFERENCES users(id) 
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (template_key) REFERENCES notification_templates(template_key) 
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='通知佇列表';

-- 站內通知表
CREATE TABLE in_app_notifications (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL COMMENT '目標使用者ID',
    
    -- 內容
    title VARCHAR(500) NOT NULL COMMENT '通知標題',
    body TEXT NOT NULL COMMENT '通知內容',
    icon VARCHAR(100) COMMENT '圖示名稱',
    image_url VARCHAR(500) COMMENT '圖片URL',
    
    -- 行為
    action_type VARCHAR(50) COMMENT '點擊行為類型（navigate, external, none）',
    action_data JSON COMMENT '行為資料（路由、URL等）',
    
    -- 狀態
    is_read BOOLEAN DEFAULT FALSE COMMENT '是否已讀',
    is_pinned BOOLEAN DEFAULT FALSE COMMENT '是否置頂',
    read_at TIMESTAMP NULL COMMENT '閱讀時間',
    
    -- 關聯資訊
    related_type VARCHAR(50) COMMENT '關聯類型（task, chat, support等）',
    related_id BIGINT UNSIGNED COMMENT '關聯ID',
    template_key VARCHAR(100) COMMENT '來源模板',
    
    -- 過期時間
    expires_at TIMESTAMP NULL COMMENT '過期時間（NULL為永不過期）',
    
    -- 時間戳記
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_user_read (user_id, is_read),
    INDEX idx_user_created (user_id, created_at DESC),
    INDEX idx_pinned (user_id, is_pinned, created_at DESC),
    INDEX idx_related (related_type, related_id),
    INDEX idx_expires (expires_at),
    
    FOREIGN KEY (user_id) REFERENCES users(id) 
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='站內通知表';

-- 通知統計表
CREATE TABLE notification_stats (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    date DATE NOT NULL COMMENT '統計日期',
    template_key VARCHAR(100) NOT NULL COMMENT '模板識別碼',
    notification_type ENUM('push', 'in_app', 'email', 'sms') NOT NULL COMMENT '通知類型',
    
    -- 統計數據
    sent_count INT DEFAULT 0 COMMENT '發送數量',
    delivered_count INT DEFAULT 0 COMMENT '送達數量',
    opened_count INT DEFAULT 0 COMMENT '開啟數量',
    clicked_count INT DEFAULT 0 COMMENT '點擊數量',
    failed_count INT DEFAULT 0 COMMENT '失敗數量',
    
    -- 時間戳記
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY uk_date_template_type (date, template_key, notification_type),
    INDEX idx_date (date),
    INDEX idx_template (template_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='通知統計表';
