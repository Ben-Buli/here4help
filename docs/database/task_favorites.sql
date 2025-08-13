-- 任務收藏功能資料表設計
-- 管理使用者收藏的任務

CREATE TABLE task_favorites (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL COMMENT '使用者ID',
    task_id BIGINT UNSIGNED NOT NULL COMMENT '任務ID', 
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '收藏時間',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    
    -- 外鍵約束
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
    
    -- 唯一約束：防止重複收藏
    UNIQUE KEY unique_user_task (user_id, task_id),
    
    -- 索引優化
    KEY idx_user_id (user_id),
    KEY idx_task_id (task_id),
    KEY idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='任務收藏表';

-- 為現有任務表添加收藏統計欄位（可選）
-- ALTER TABLE tasks ADD COLUMN favorites_count INT UNSIGNED DEFAULT 0 COMMENT '收藏數量';

-- 示例：查詢使用者收藏的任務
/*
SELECT t.*, tf.created_at as favorited_at 
FROM tasks t 
INNER JOIN task_favorites tf ON t.id = tf.task_id 
WHERE tf.user_id = ? 
ORDER BY tf.created_at DESC;
*/

-- 示例：檢查使用者是否收藏某任務
/*
SELECT EXISTS(
    SELECT 1 FROM task_favorites 
    WHERE user_id = ? AND task_id = ?
) as is_favorited;
*/

-- 示例：收藏/取消收藏任務
/*
-- 收藏
INSERT INTO task_favorites (user_id, task_id) VALUES (?, ?) 
ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;

-- 取消收藏
DELETE FROM task_favorites WHERE user_id = ? AND task_id = ?;
*/