-- 為 chat_reads 表添加自增 ID
-- 日期：2025-08-16
-- 目的：為 chat_reads 表添加自增主鍵 ID

-- 步驟 1: 檢查當前表結構
SELECT '檢查當前 chat_reads 表結構' AS step;
DESCRIBE chat_reads;

-- 步驟 2: 備份現有資料
CREATE TABLE IF NOT EXISTS chat_reads_backup_20250816 AS SELECT * FROM chat_reads;
SELECT '已備份 chat_reads 資料到 chat_reads_backup_20250816' AS status;

-- 步驟 3: 添加自增 ID 欄位
ALTER TABLE chat_reads ADD COLUMN id bigint NOT NULL AUTO_INCREMENT FIRST, ADD PRIMARY KEY (id);
SELECT '已添加自增 ID 欄位' AS status;

-- 步驟 4: 驗證修改結果
SELECT '驗證修改後的表結構' AS step;
DESCRIBE chat_reads;

-- 步驟 5: 檢查資料完整性
SELECT '檢查資料完整性' AS step;
SELECT COUNT(*) AS total_records FROM chat_reads;
SELECT COUNT(*) AS backup_records FROM chat_reads_backup_20250816;

-- 步驟 6: 驗證唯一約束
SELECT '驗證唯一約束' AS step;
SELECT user_id, room_id, COUNT(*) as count 
FROM chat_reads 
GROUP BY user_id, room_id 
HAVING COUNT(*) > 1;

-- 步驟 7: 顯示前幾筆資料作為驗證
SELECT '顯示前 5 筆資料作為驗證' AS step;
SELECT id, user_id, room_id, last_read_message_id, updated_at 
FROM chat_reads 
ORDER BY id 
LIMIT 5;

-- 完成訊息
SELECT 'chat_reads 表自增 ID 添加完成！' AS completion_status;
