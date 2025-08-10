-- 清理 chat_reads 表：移除臨時欄位，處理未轉換的資料
-- 執行前請先備份！

START TRANSACTION;

-- 步驟 1: 處理剩餘的字串格式 room_id_str
-- 將未轉換的 task_xxx_pair_x_y 格式轉換為對應的數字房間號

UPDATE chat_reads cr
JOIN chat_rooms r ON (
  CONCAT('task_', r.task_id, '_pair_', r.creator_id, '_', r.participant_id) = cr.room_id_str
)
SET cr.room_id = r.id
WHERE cr.room_id = 0 
  AND cr.room_id_str LIKE 'task_%_pair_%_%';

-- 步驟 2: 刪除無法對應的舊格式記錄（如果有的話）
DELETE FROM chat_reads 
WHERE room_id = 0 
  AND room_id_str IS NOT NULL 
  AND room_id_str != '';

-- 步驟 3: 移除臨時欄位（使用條件檢查）
SET @room_id_str_exists = (
  SELECT COUNT(*) 
  FROM INFORMATION_SCHEMA.COLUMNS 
  WHERE TABLE_SCHEMA = 'hero4helpdemofhs_hero4help' 
    AND TABLE_NAME = 'chat_reads' 
    AND COLUMN_NAME = 'room_id_str'
);

SET @room_id_num_exists = (
  SELECT COUNT(*) 
  FROM INFORMATION_SCHEMA.COLUMNS 
  WHERE TABLE_SCHEMA = 'hero4helpdemofhs_hero4help' 
    AND TABLE_NAME = 'chat_reads' 
    AND COLUMN_NAME = 'room_id_num'
);

SET @sql1 = IF(@room_id_str_exists > 0, 'ALTER TABLE chat_reads DROP COLUMN room_id_str', 'SELECT "room_id_str column not found" AS status');
SET @sql2 = IF(@room_id_num_exists > 0, 'ALTER TABLE chat_reads DROP COLUMN room_id_num', 'SELECT "room_id_num column not found" AS status');

PREPARE stmt1 FROM @sql1;
EXECUTE stmt1;
DEALLOCATE PREPARE stmt1;

PREPARE stmt2 FROM @sql2;
EXECUTE stmt2;
DEALLOCATE PREPARE stmt2;

-- 步驟 4: 確保主鍵和索引正確
-- 檢查是否已有主鍵
SET @has_primary = (
  SELECT COUNT(*) 
  FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
  WHERE TABLE_SCHEMA = 'hero4helpdemofhs_hero4help' 
    AND TABLE_NAME = 'chat_reads' 
    AND CONSTRAINT_NAME = 'PRIMARY'
);

SET @sql3 = IF(@has_primary > 0, 'ALTER TABLE chat_reads DROP PRIMARY KEY', 'SELECT "No primary key to drop" AS status');
PREPARE stmt3 FROM @sql3;
EXECUTE stmt3;
DEALLOCATE PREPARE stmt3;

-- 添加主鍵
ALTER TABLE chat_reads ADD PRIMARY KEY (user_id, room_id);

-- 確保外鍵約束存在
ALTER TABLE chat_reads 
  ADD CONSTRAINT fk_chat_reads_room 
  FOREIGN KEY (room_id) REFERENCES chat_rooms(id) ON DELETE CASCADE;

ALTER TABLE chat_reads 
  ADD CONSTRAINT fk_chat_reads_user 
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- 步驟 5: 重建索引
CREATE INDEX idx_room_user ON chat_reads(room_id, user_id);

COMMIT;

-- 驗證結果
SELECT 'Cleanup completed. Verification:' AS status;
SELECT COUNT(*) AS total_reads FROM chat_reads;
SELECT user_id, room_id, last_read_message_id FROM chat_reads ORDER BY user_id, room_id;