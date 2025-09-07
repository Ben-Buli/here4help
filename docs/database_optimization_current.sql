-- 方案 2：保持現狀但優化查詢和索引
-- 1. 添加複合索引提升查詢性能
CREATE INDEX idx_task_applications_user_status ON task_applications(user_id, status);
CREATE INDEX idx_tasks_status_id ON tasks(status_id);
CREATE INDEX idx_task_statuses_code ON task_statuses(code);

-- 2. 優化查詢語句
-- 使用 EXISTS 子查詢可能比 JOIN 更高效
SELECT COUNT(*) as completed_tasks
FROM task_applications ta
WHERE ta.user_id = ? 
AND ta.status = 'accepted'
AND EXISTS (
    SELECT 1 FROM tasks t
    JOIN task_statuses ts ON ts.id = t.status_id
    WHERE t.id = ta.task_id 
    AND ts.code = 'completed'
);

-- 3. 添加狀態一致性檢查
-- 定期檢查數據一致性的存儲過程
DELIMITER //
CREATE PROCEDURE CheckApplicationTaskStatusConsistency()
BEGIN
    SELECT 
        ta.id as application_id,
        ta.task_id,
        ta.status as application_status,
        ts.code as task_status,
        'Inconsistent' as issue
    FROM task_applications ta
    JOIN tasks t ON t.id = ta.task_id
    JOIN task_statuses ts ON ts.id = t.status_id
    WHERE ta.status = 'accepted' 
    AND ts.code NOT IN ('in_progress', 'completed', 'pending_confirmation')
    UNION ALL
    SELECT 
        ta.id as application_id,
        ta.task_id,
        ta.status as application_status,
        ts.code as task_status,
        'Inconsistent' as issue
    FROM task_applications ta
    JOIN tasks t ON t.id = ta.task_id
    JOIN task_statuses ts ON ts.id = t.status_id
    WHERE ta.status = 'rejected' 
    AND ts.code = 'completed';
END //
DELIMITER ;
