# 🔧 手動修正 Accepted 分頁測試資料

## 問題說明

由於資料庫觸發器 `trg_app_insert_auto_reject` 和 `trg_app_update_auto_reject` 阻止了自動創建/修改 `task_applications` 記錄，導致 Accepted 分頁沒有測試資料。

## 🛠️ 手動解決方案

### 方法1: 直接在資料庫中操作

1. **連接到 MySQL 資料庫** (MAMP phpMyAdmin 或命令行)
2. **執行以下 SQL 語句**:

```sql
-- 1. 暫時禁用觸發器
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO';
SET foreign_key_checks = 0;

-- 2. 直接插入 accepted 應徵記錄
INSERT IGNORE INTO task_applications (task_id, user_id, status, created_at, updated_at) VALUES
('accepted-test-001', 2, 'accepted', NOW(), NOW()),
('accepted-test-002', 2, 'accepted', NOW(), NOW()),
('accepted-test-003', 2, 'accepted', NOW(), NOW());

-- 3. 恢復設定
SET foreign_key_checks = 1;
SET SQL_MODE=@OLD_SQL_MODE;
```

### 方法2: 修改現有資料

如果上述方法不行，可以直接修改現有的 `applied` 記錄：

```sql
-- 將一些 applied 記錄改為 accepted
UPDATE task_applications 
SET status = 'accepted', updated_at = NOW() 
WHERE user_id = 2 AND status = 'applied' 
LIMIT 3;
```

### 方法3: 暫時禁用觸發器

```sql
-- 查看觸發器
SHOW TRIGGERS LIKE 'task_applications';

-- 刪除觸發器 (謹慎操作)
DROP TRIGGER IF EXISTS trg_app_insert_auto_reject;
DROP TRIGGER IF EXISTS trg_app_update_auto_reject;

-- 插入測試資料
INSERT INTO task_applications (task_id, user_id, status, created_at, updated_at) VALUES
('accepted-test-001', 2, 'accepted', NOW(), NOW()),
('accepted-test-002', 2, 'accepted', NOW(), NOW()),
('accepted-test-003', 2, 'accepted', NOW(), NOW());

-- 重新創建觸發器 (如果需要)
-- 這裡需要原始的觸發器定義
```

## 🚀 驗證修正結果

執行以下查詢確認資料正確：

```sql
-- 檢查 accepted 記錄
SELECT t.id, t.title, t.status_id, ts.display_name, ta.status
FROM tasks t
JOIN task_applications ta ON t.id = ta.task_id AND ta.status = 'accepted'
JOIN task_statuses ts ON ts.id = t.status_id
WHERE ta.user_id = 2;
```

預期結果應該顯示 3 個任務：
- `accepted-test-001` - Completed (有評分)
- `accepted-test-002` - Completed (無評分) 
- `accepted-test-003` - In Progress

## 📱 前端測試

修正後，Accepted 分頁應該顯示：

1. **✅ Completed + 已評分** → 顯示 ⭐4 (可點擊查看)
2. **⏳ Completed + 未評分** → 顯示 "Awaiting review"
3. **📋 In Progress** → 顯示 "In Progress" 狀態標籤

## 🔄 替代測試方案

如果手動修正太複雜，可以：

1. **測試 Posted 和 Not Selected 分頁** - 這些已經有完整測試資料
2. **模擬 Accepted 場景** - 在 Posted 分頁中測試評分功能
3. **檢查 API 邏輯** - 直接測試 `backend/api/ratings/accepted.php`

## 📞 需要協助

如果需要協助執行手動修正，請告知：
1. 你偏好哪種方法
2. 是否可以直接操作資料庫
3. 是否需要我提供更詳細的步驟
