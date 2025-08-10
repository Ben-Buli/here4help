-- 統一聊天室 ID 格式：從字串轉為數字主鍵
-- 執行前請先備份資料庫！

START TRANSACTION;

-- 步驟 1: 新增臨時表結構
CREATE TABLE IF NOT EXISTS chat_rooms_new (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  task_id VARCHAR(36) NOT NULL,
  creator_id BIGINT NOT NULL,
  participant_id BIGINT NOT NULL,
  type ENUM('task') DEFAULT 'task',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_task_room (task_id, creator_id, participant_id),
  KEY idx_task_id (task_id),
  KEY idx_creator_id (creator_id),
  KEY idx_participant_id (participant_id),
  CONSTRAINT fk_rooms_task FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  CONSTRAINT fk_rooms_creator FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_rooms_participant FOREIGN KEY (participant_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 步驟 2: 遷移現有資料（如果有的話）
-- 從舊的字串格式 room_id 解析並創建新房間記錄
INSERT INTO chat_rooms_new (task_id, creator_id, participant_id, type, created_at)
SELECT DISTINCT 
  SUBSTRING_INDEX(SUBSTRING_INDEX(old_room.id, '_pair_', 1), 'task_', -1) AS task_id,
  CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(old_room.id, '_pair_', -1), '_', 1) AS UNSIGNED) AS creator_id,
  CAST(SUBSTRING_INDEX(old_room.id, '_', -1) AS UNSIGNED) AS participant_id,
  'task' AS type,
  old_room.created_at
FROM chat_rooms old_room
WHERE old_room.id LIKE 'task_%_pair_%_%'
  AND SUBSTRING_INDEX(SUBSTRING_INDEX(old_room.id, '_pair_', 1), 'task_', -1) IN (SELECT id FROM tasks)
ON DUPLICATE KEY UPDATE id = id;

-- 步驟 3: 創建新的 chat_messages 表
CREATE TABLE IF NOT EXISTS chat_messages_new (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  room_id BIGINT NOT NULL,
  from_user_id BIGINT NOT NULL,
  message TEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_room_created (room_id, created_at),
  KEY idx_from_user (from_user_id),
  CONSTRAINT fk_messages_room FOREIGN KEY (room_id) REFERENCES chat_rooms_new(id) ON DELETE CASCADE,
  CONSTRAINT fk_messages_user FOREIGN KEY (from_user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 步驟 4: 遷移訊息資料
INSERT INTO chat_messages_new (room_id, from_user_id, message, created_at)
SELECT 
  rn.id AS room_id,
  om.from_user_id,
  om.message,
  om.created_at
FROM chat_messages om
JOIN chat_rooms_new rn ON CONCAT('task_', rn.task_id, '_pair_', rn.creator_id, '_', rn.participant_id) = om.room_id;

-- 步驟 5: 創建新的 chat_reads 表
CREATE TABLE IF NOT EXISTS chat_reads_new (
  user_id BIGINT NOT NULL,
  room_id BIGINT NOT NULL,
  last_read_message_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, room_id),
  KEY idx_room_user (room_id, user_id),
  CONSTRAINT fk_reads_room FOREIGN KEY (room_id) REFERENCES chat_rooms_new(id) ON DELETE CASCADE,
  CONSTRAINT fk_reads_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 步驟 6: 遷移讀取記錄
INSERT INTO chat_reads_new (user_id, room_id, last_read_message_id, updated_at)
SELECT 
  or_read.user_id,
  rn.id AS room_id,
  or_read.last_read_message_id,
  or_read.updated_at
FROM chat_reads or_read
JOIN chat_rooms_new rn ON CONCAT('task_', rn.task_id, '_pair_', rn.creator_id, '_', rn.participant_id) = or_read.room_id;

-- 步驟 7: 備份舊表並重命名新表
DROP TABLE IF EXISTS chat_reads_backup;
DROP TABLE IF EXISTS chat_messages_backup;
DROP TABLE IF EXISTS chat_rooms_backup;

RENAME TABLE chat_reads TO chat_reads_backup;
RENAME TABLE chat_messages TO chat_messages_backup;
RENAME TABLE chat_rooms TO chat_rooms_backup;

RENAME TABLE chat_reads_new TO chat_reads;
RENAME TABLE chat_messages_new TO chat_messages;
RENAME TABLE chat_rooms_new TO chat_rooms;

COMMIT;

-- 驗證查詢
SELECT 'Migration completed. Verification:' AS status;
SELECT COUNT(*) AS total_rooms FROM chat_rooms;
SELECT COUNT(*) AS total_messages FROM chat_messages;
SELECT COUNT(*) AS total_reads FROM chat_reads;

-- 顯示幾個範例記錄
SELECT id, task_id, creator_id, participant_id FROM chat_rooms LIMIT 5;