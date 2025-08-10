-- 統一 chat_messages 表的欄位名稱和結構

START TRANSACTION;

-- 檢查現有欄位並統一為標準格式
-- 如果有 sender_id 但沒有 from_user_id，重命名
SET @col_exists = (
  SELECT COUNT(*) 
  FROM INFORMATION_SCHEMA.COLUMNS 
  WHERE TABLE_SCHEMA = 'hero4helpdemofhs_hero4help' 
    AND TABLE_NAME = 'chat_messages' 
    AND COLUMN_NAME = 'sender_id'
);

SET @from_col_exists = (
  SELECT COUNT(*) 
  FROM INFORMATION_SCHEMA.COLUMNS 
  WHERE TABLE_SCHEMA = 'hero4helpdemofhs_hero4help' 
    AND TABLE_NAME = 'chat_messages' 
    AND COLUMN_NAME = 'from_user_id'
);

-- 如果只有 sender_id 沒有 from_user_id，重命名
SET @sql = IF(@col_exists > 0 AND @from_col_exists = 0,
  'ALTER TABLE chat_messages CHANGE sender_id from_user_id BIGINT UNSIGNED NOT NULL',
  'SELECT "No column rename needed" AS status'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 移除不需要的欄位（如果存在）
SET @drop_cols = '';

-- 檢查並移除 sender_type（如果存在且已有 from_user_id）
SET @sender_type_exists = (
  SELECT COUNT(*) 
  FROM INFORMATION_SCHEMA.COLUMNS 
  WHERE TABLE_SCHEMA = 'hero4helpdemofhs_hero4help' 
    AND TABLE_NAME = 'chat_messages' 
    AND COLUMN_NAME = 'sender_type'
);

SET @sql = IF(@sender_type_exists > 0,
  'ALTER TABLE chat_messages DROP COLUMN sender_type',
  'SELECT "No sender_type column to drop" AS status'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 檢查並移除 kind（如果不需要）
SET @kind_exists = (
  SELECT COUNT(*) 
  FROM INFORMATION_SCHEMA.COLUMNS 
  WHERE TABLE_SCHEMA = 'hero4helpdemofhs_hero4help' 
    AND TABLE_NAME = 'chat_messages' 
    AND COLUMN_NAME = 'kind'
);

-- 保留 kind 欄位，但確保預設值正確
SET @sql = IF(@kind_exists > 0,
  'ALTER TABLE chat_messages MODIFY COLUMN kind ENUM("user", "system") DEFAULT "user"',
  'SELECT "No kind column found" AS status'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 確保 from_user_id 欄位類型正確（BIGINT UNSIGNED）
ALTER TABLE chat_messages MODIFY COLUMN from_user_id BIGINT UNSIGNED NOT NULL;

-- 移除現有的外鍵約束（如果存在）
SET @fk_room_exists = (
  SELECT COUNT(*) 
  FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
  WHERE TABLE_SCHEMA = 'hero4helpdemofhs_hero4help' 
    AND TABLE_NAME = 'chat_messages' 
    AND CONSTRAINT_NAME = 'fk_chat_messages_room'
);

SET @fk_user_exists = (
  SELECT COUNT(*) 
  FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
  WHERE TABLE_SCHEMA = 'hero4helpdemofhs_hero4help' 
    AND TABLE_NAME = 'chat_messages' 
    AND CONSTRAINT_NAME = 'fk_chat_messages_user'
);

SET @sql_room = IF(@fk_room_exists > 0, 'ALTER TABLE chat_messages DROP FOREIGN KEY fk_chat_messages_room', 'SELECT "No room FK to drop" AS status');
SET @sql_user = IF(@fk_user_exists > 0, 'ALTER TABLE chat_messages DROP FOREIGN KEY fk_chat_messages_user', 'SELECT "No user FK to drop" AS status');

PREPARE stmt_room FROM @sql_room;
EXECUTE stmt_room;
DEALLOCATE PREPARE stmt_room;

PREPARE stmt_user FROM @sql_user;
EXECUTE stmt_user;
DEALLOCATE PREPARE stmt_user;

-- 重新添加外鍵約束
ALTER TABLE chat_messages 
  ADD CONSTRAINT fk_chat_messages_room 
  FOREIGN KEY (room_id) REFERENCES chat_rooms(id) ON DELETE CASCADE;

ALTER TABLE chat_messages 
  ADD CONSTRAINT fk_chat_messages_user 
  FOREIGN KEY (from_user_id) REFERENCES users(id) ON DELETE CASCADE;

-- 確保索引存在
CREATE INDEX idx_room_created ON chat_messages(room_id, created_at);
CREATE INDEX idx_from_user ON chat_messages(from_user_id);

COMMIT;

-- 驗證最終結構
DESCRIBE chat_messages;