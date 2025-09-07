-- 改進方案：統一使用 task_statuses 表
-- 1. 為 task_applications 添加 status_id 外鍵
ALTER TABLE task_applications 
ADD COLUMN status_id INT NULL,
ADD FOREIGN KEY (status_id) REFERENCES task_statuses(id);

-- 2. 創建應用狀態專用的狀態記錄
INSERT INTO task_statuses (code, name, description) VALUES
('applied', 'Applied', 'Application submitted'),
('accepted', 'Accepted', 'Application accepted by creator'),
('rejected', 'Rejected', 'Application rejected by creator'),
('withdrawn', 'Withdrawn', 'Application withdrawn by applicant');

-- 3. 遷移現有數據
UPDATE task_applications ta
SET status_id = (
    SELECT id FROM task_statuses 
    WHERE code = ta.status
);

-- 4. 添加索引
CREATE INDEX idx_task_applications_user_status_id ON task_applications(user_id, status_id);

-- 5. 更新查詢邏輯
SELECT COUNT(*) as completed_tasks
FROM task_applications ta
JOIN tasks t ON t.id = ta.task_id
JOIN task_statuses tas ON tas.id = ta.status_id
JOIN task_statuses tts ON tts.id = t.status_id
WHERE ta.user_id = ? 
AND tas.code = 'accepted'
AND tts.code = 'completed';
