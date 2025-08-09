-- Backfill creator_id from tasks.creator_name when user name is uniquely mapped

-- 1) Update creator_id only for names that uniquely map to one user
UPDATE tasks t
JOIN (
  SELECT name, MIN(id) AS user_id
  FROM users
  GROUP BY name
  HAVING COUNT(*) = 1
) m ON m.name = t.creator_name
SET t.creator_id = m.user_id
WHERE t.creator_id IS NULL AND t.creator_name IS NOT NULL AND t.creator_name <> '';

-- 2) Optional: report ambiguous names (manual check)
-- SELECT t.creator_name, COUNT(*) AS user_count
-- FROM tasks t
-- JOIN users u ON u.name = t.creator_name
-- WHERE t.creator_id IS NULL
-- GROUP BY t.creator_name
-- HAVING user_count > 1;

-- 3) Recommended indexes
-- ALTER TABLE tasks ADD INDEX idx_tasks_creator_id (creator_id);
-- ALTER TABLE tasks ADD INDEX idx_tasks_status_id (status_id);

