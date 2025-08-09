-- Add status_id, creator_id, acceptor_id (nullable initially)
ALTER TABLE tasks
  ADD COLUMN status_id INT NULL AFTER status,
  ADD COLUMN creator_id BIGINT NULL AFTER creator_name,
  ADD COLUMN acceptor_id BIGINT NULL AFTER creator_id;

-- Backfill status_id from status string if possible
UPDATE tasks t
JOIN task_statuses s ON s.code = LOWER(REPLACE(t.status, ' ', '_'))
SET t.status_id = s.id
WHERE t.status IS NOT NULL AND t.status <> '';

-- Optional backfill for creator_id if a unique mapping is available (example using users.name)
-- UPDATE tasks t
-- JOIN users u ON u.name = t.creator_name
-- SET t.creator_id = u.id
-- WHERE t.creator_name IS NOT NULL AND t.creator_name <> '';

-- Add foreign keys (keep NULLable during transition)
ALTER TABLE tasks
  ADD CONSTRAINT fk_tasks_status FOREIGN KEY (status_id) REFERENCES task_statuses(id),
  ADD CONSTRAINT fk_tasks_creator FOREIGN KEY (creator_id) REFERENCES users(id),
  ADD CONSTRAINT fk_tasks_acceptor FOREIGN KEY (acceptor_id) REFERENCES users(id);

