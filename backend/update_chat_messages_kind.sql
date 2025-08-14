-- 修改 chat_messages 表的 kind 欄位，支援 applyMessage 類型
ALTER TABLE chat_messages MODIFY COLUMN kind ENUM('user', 'system', 'applyMessage') DEFAULT 'user';

-- 檢查修改結果
DESCRIBE chat_messages; 