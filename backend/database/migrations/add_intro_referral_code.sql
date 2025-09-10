-- 新增 intro_referral_code 欄位到 users 表
-- 執行日期: 2025-01-10

-- 新增 intro_referral_code 欄位
ALTER TABLE users ADD COLUMN intro_referral_code VARCHAR(12) NULL DEFAULT NULL COMMENT '被推薦碼';

-- 新增索引以提升查詢效能
ALTER TABLE users ADD INDEX idx_intro_referral_code (intro_referral_code);

-- 確保 referral_code 欄位為12碼長度
ALTER TABLE users MODIFY COLUMN referral_code VARCHAR(12) NULL DEFAULT NULL COMMENT '推薦碼';

-- 新增索引以提升查詢效能
ALTER TABLE users ADD INDEX idx_referral_code (referral_code);

-- 檢查欄位是否成功新增
SELECT 
    COLUMN_NAME, 
    DATA_TYPE, 
    CHARACTER_MAXIMUM_LENGTH, 
    IS_NULLABLE, 
    COLUMN_DEFAULT, 
    COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = DATABASE() 
    AND TABLE_NAME = 'users' 
    AND COLUMN_NAME IN ('intro_referral_code', 'referral_code')
ORDER BY COLUMN_NAME;
