-- 任務爭議模組資料庫修正腳本
-- 執行日期: 2025-01-03
-- 目的: 修正外鍵類型不匹配和添加必要索引

-- 1. 檢查當前 chat_rooms.id 的類型
-- 如果是 bigint，我們需要確保 task_dispute_events.task_dispute_chat_room_id 也是 bigint
-- 如果是 VARCHAR(128)，我們需要修正 task_dispute_events.task_dispute_chat_room_id

-- 首先，檢查是否存在 task_dispute_events 表
-- 如果不存在，創建它

CREATE TABLE IF NOT EXISTS `task_dispute_events` (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `task_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '關聯的任務',
  `task_dispute_chat_room_id` bigint NOT NULL COMMENT '爭議聊天室ID - 匹配 chat_rooms.id 類型',
  `user_id` bigint UNSIGNED NOT NULL COMMENT '提案人 (用戶)',
  `admin_id` int DEFAULT NULL COMMENT '處理的管理員',
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '爭議標題',
  `description` text COLLATE utf8mb4_unicode_ci COMMENT '爭議描述',
  `status` enum('submitted','in_progress','resolved') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'submitted' COMMENT '事件流程狀態',
  `decision_result` enum('completed','back_to_progress','reset') COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '管理員裁決結果',
  `decision_note` text COLLATE utf8mb4_unicode_ci COMMENT '管理員裁決說明',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='任務爭議事件表';

-- 創建 task_dispute_event_logs 表
CREATE TABLE IF NOT EXISTS `task_dispute_event_logs` (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `event_id` bigint UNSIGNED NOT NULL COMMENT '關聯的爭議事件ID',
  `admin_id` int DEFAULT NULL COMMENT '操作的管理員',
  `old_status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '舊狀態',
  `new_status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '新狀態',
  `old_decision` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '舊決策',
  `new_decision` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '新決策',
  `note` text COLLATE utf8mb4_unicode_ci COMMENT '操作說明',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='任務爭議事件日誌表';

-- 2. 添加索引 (方案A - 保守執行)
-- 爭議模組必需索引
CREATE INDEX IF NOT EXISTS idx_task_dispute_events_task_id ON task_dispute_events(task_id);
CREATE INDEX IF NOT EXISTS idx_task_dispute_events_user_id ON task_dispute_events(user_id);
CREATE INDEX IF NOT EXISTS idx_task_dispute_events_status ON task_dispute_events(status);
CREATE INDEX IF NOT EXISTS idx_task_dispute_events_created_at ON task_dispute_events(created_at);
CREATE UNIQUE INDEX IF NOT EXISTS uk_task_dispute_events_chat_room ON task_dispute_events(task_dispute_chat_room_id);

-- task_dispute_event_logs 表索引
CREATE INDEX IF NOT EXISTS idx_task_dispute_event_logs_event_id ON task_dispute_event_logs(event_id);
CREATE INDEX IF NOT EXISTS idx_task_dispute_event_logs_admin_id ON task_dispute_event_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_task_dispute_event_logs_created_at ON task_dispute_event_logs(created_at);

-- 低風險高收益的現有表格索引
CREATE INDEX IF NOT EXISTS idx_chat_messages_room_kind_created ON chat_messages(room_id, kind, created_at);

-- 3. 添加外鍵約束 (如果不存在)
-- 注意: 在添加外鍵之前，確保參考的表和欄位存在且類型匹配

-- task_dispute_events 外鍵
ALTER TABLE task_dispute_events 
ADD CONSTRAINT IF NOT EXISTS fk_task_dispute_events_task 
FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE;

ALTER TABLE task_dispute_events 
ADD CONSTRAINT IF NOT EXISTS fk_task_dispute_events_chat_room 
FOREIGN KEY (task_dispute_chat_room_id) REFERENCES chat_rooms(id) ON DELETE CASCADE;

ALTER TABLE task_dispute_events 
ADD CONSTRAINT IF NOT EXISTS fk_task_dispute_events_user 
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE task_dispute_events 
ADD CONSTRAINT IF NOT EXISTS fk_task_dispute_events_admin 
FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE SET NULL;

-- task_dispute_event_logs 外鍵
ALTER TABLE task_dispute_event_logs 
ADD CONSTRAINT IF NOT EXISTS fk_dispute_logs_event 
FOREIGN KEY (event_id) REFERENCES task_dispute_events(id) ON DELETE CASCADE;

ALTER TABLE task_dispute_event_logs 
ADD CONSTRAINT IF NOT EXISTS fk_dispute_logs_admin 
FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE SET NULL;

-- 4. 驗證腳本 - 檢查表結構
SELECT 'task_dispute_events table structure:' as info;
DESCRIBE task_dispute_events;

SELECT 'task_dispute_event_logs table structure:' as info;
DESCRIBE task_dispute_event_logs;

-- 檢查索引
SELECT 'task_dispute_events indexes:' as info;
SHOW INDEX FROM task_dispute_events;

-- 檢查外鍵約束
SELECT 'Foreign key constraints:' as info;
SELECT 
    TABLE_NAME,
    COLUMN_NAME,
    CONSTRAINT_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM 
    INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
WHERE 
    REFERENCED_TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME IN ('task_dispute_events', 'task_dispute_event_logs');

SELECT 'Database fixes completed successfully!' as result;
