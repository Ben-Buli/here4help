-- Enforce creator_id and drop legacy creator_name from tasks
-- NOTE: 預設以 users.name 做唯一映射。若要改用 email/username，請改寫下方 JOIN 條件。

START TRANSACTION;

-- 1) 確保欄位存在（若前面遷移已添加可忽略錯誤）
-- ALTER TABLE tasks ADD COLUMN creator_id BIGINT NULL AFTER creator_name;

-- 2) 回填（僅唯一 name 對應）
UPDATE tasks t
JOIN (
  SELECT name, MIN(id) AS user_id
  FROM users
  GROUP BY name
  HAVING COUNT(*) = 1
) m ON m.name = t.creator_name
SET t.creator_id = m.user_id
WHERE t.creator_id IS NULL AND t.creator_name IS NOT NULL AND t.creator_name <> '';

-- 如要改用 email 映射，請改為：
-- UPDATE tasks t
-- JOIN users u ON u.email = t.creator_name
-- SET t.creator_id = u.id
-- WHERE t.creator_id IS NULL AND t.creator_name IS NOT NULL AND t.creator_name <> '';

-- 3) 檢查未匹配與重名（請先人工處理後再繼續）
-- 未匹配：
-- SELECT COUNT(*) AS remaining_null FROM tasks WHERE creator_id IS NULL;
-- 重名清單：
-- SELECT t.creator_name, COUNT(*) c FROM users u JOIN tasks t ON u.name = t.creator_name GROUP BY t.creator_name HAVING c > 1;

-- 4) 強制 NOT NULL（若仍有 NULL 會失敗，請先處理 3）
ALTER TABLE tasks MODIFY COLUMN creator_id BIGINT NOT NULL;

-- 5) 索引
ALTER TABLE tasks ADD INDEX idx_tasks_creator_id (creator_id);

-- 6) 外鍵（若已存在可忽略錯誤或先手動刪除同名約束）
-- ALTER TABLE tasks
--   ADD CONSTRAINT fk_tasks_creator FOREIGN KEY (creator_id) REFERENCES users(id);

-- 7) 移除舊欄位
ALTER TABLE tasks DROP COLUMN creator_name;

COMMIT;

