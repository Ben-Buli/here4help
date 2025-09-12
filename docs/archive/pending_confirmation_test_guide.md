# Pending Confirmation 七日倒數測試指南

## 測試環境設置

### 1. 管理員權限設置 (Permission 99)

#### 後端設置管理員用戶
```sql
-- 設置測試管理員帳號
UPDATE users SET permission = 99 WHERE id = YOUR_USER_ID;

-- 驗證權限設置
SELECT id, name, email, permission FROM users WHERE permission = 99;
```

#### 前端權限檢查
- 管理員權限檢查：`PermissionService.canAccessAdmin(permission)`
- 權限值 99 = 管理員
- 可以看到 "Time Up" 按鈕在 pending_confirmation 狀態的任務卡片上

### 2. 測試用倒數時間設置

#### 方法一：修改前端倒數時間（推薦）

**修改文件**：`lib/chat/widgets/task_card_components.dart`

```dart
// 第 271 行，將 7 天改為 10 秒
const totalPendingTime = Duration(seconds: 10); // 原本是 Duration(days: 7)
```

**修改文件**：`lib/chat/pages/chat_detail_page.dart`

```dart
// 第 1744 行，將 7 天改為 10 秒
const totalPendingTime = Duration(seconds: 10); // 原本是 Duration(days: 7)
```

#### 方法二：修改後端自動完成邏輯

**修改文件**：`backend/cron/auto_complete_tasks.php`

```php
// 第 63 行，將 7 天改為 10 秒測試
WHERE ts.code = 'pending_confirmation'
AND TIMESTAMPDIFF(SECOND, t.updated_at, NOW()) >= 10  -- 原本是 DATEDIFF(NOW(), t.updated_at) >= 7
```

### 3. 測試流程

#### 步驟 1：創建測試任務
1. 創建一個新任務
2. 找到應徵者並接受應徵
3. 將任務狀態設為 "in_progress"

#### 步驟 2：觸發 Pending Confirmation
1. 在聊天室中點擊 "Mark as Completed" 按鈕
2. 任務狀態變為 "pending_confirmation"
3. 開始 7 日倒數（或測試用的 10 秒倒數）

#### 步驟 3：觀察倒數計時
- 前端會顯示倒數計時器
- 格式：`⏰ Xd XX:XX:XX until auto complete`
- 倒數結束後會自動隱藏

#### 步驟 4：測試管理員 Time Up 功能
1. 使用 permission = 99 的帳號登入
2. 在 Posted Tasks 頁面找到 pending_confirmation 狀態的任務
3. 應該看到 "Time Up" 按鈕
4. 點擊 "Time Up" 按鈕可以立即完成任務

#### 步驟 5：測試自動完成
1. 等待倒數時間結束（10 秒）
2. 執行後端自動完成腳本：
   ```bash
   cd /Users/eliasscott/here4help/backend
   php cron/auto_complete_tasks.php
   ```
3. 檢查任務狀態是否自動變為 "completed"
4. 檢查點數是否正確轉移

## 測試用快速設置腳本

### 前端快速測試設置
```dart
// 在 lib/chat/widgets/task_card_components.dart 中
// 找到第 271 行並替換為：
const totalPendingTime = Duration(seconds: 10); // 測試用：10秒倒數

// 在 lib/chat/pages/chat_detail_page.dart 中  
// 找到第 1744 行並替換為：
const totalPendingTime = Duration(seconds: 10); // 測試用：10秒倒數
```

### 後端測試腳本
```php
<?php
// 創建測試用自動完成腳本：backend/test_auto_complete.php
require_once __DIR__ . '/config/database.php';

$db = Database::getInstance()->getConnection();

// 查找測試用的 pending confirmation 任務（10秒後自動完成）
$sql = "
    SELECT 
        t.id,
        t.title,
        t.updated_at,
        TIMESTAMPDIFF(SECOND, t.updated_at, NOW()) as seconds_pending
    FROM tasks t
    JOIN task_statuses ts ON t.status_id = ts.id
    WHERE ts.code = 'pending_confirmation'
    AND TIMESTAMPDIFF(SECOND, t.updated_at, NOW()) >= 10
";

$stmt = $db->prepare($sql);
$stmt->execute();
$tasks = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "找到 " . count($tasks) . " 個需要自動完成的任務\n";
foreach ($tasks as $task) {
    echo "任務 {$task['id']}: {$task['title']} (等待 {$task['seconds_pending']} 秒)\n";
}
?>
```

## 測試檢查點

### 前端檢查
- [ ] 倒數計時器正確顯示
- [ ] 倒數時間準確（10秒測試）
- [ ] 時間到後計時器消失
- [ ] 管理員可以看到 "Time Up" 按鈕
- [ ] 一般用戶看不到 "Time Up" 按鈕

### 後端檢查
- [ ] 自動完成腳本正確識別超時任務
- [ ] 任務狀態正確更新為 "completed"
- [ ] 點數正確轉移給任務執行者
- [ ] 手續費正確計算和扣除
- [ ] 系統日誌正確記錄

### 資料庫檢查
```sql
-- 檢查任務狀態
SELECT t.id, t.title, ts.code as status, t.updated_at 
FROM tasks t 
JOIN task_statuses ts ON t.status_id = ts.id 
WHERE t.id = YOUR_TASK_ID;

-- 檢查點數轉移記錄
SELECT * FROM point_transactions 
WHERE task_id = YOUR_TASK_ID 
ORDER BY created_at DESC;

-- 檢查任務日誌
SELECT * FROM task_logs 
WHERE task_id = YOUR_TASK_ID 
ORDER BY created_at DESC;
```

## 恢復生產設置

測試完成後，記得將倒數時間改回 7 天：

```dart
// 恢復 lib/chat/widgets/task_card_components.dart
const totalPendingTime = Duration(days: 7);

// 恢復 lib/chat/pages/chat_detail_page.dart
const totalPendingTime = Duration(days: 7);
```

```php
// 恢復 backend/cron/auto_complete_tasks.php
WHERE ts.code = 'pending_confirmation'
AND DATEDIFF(NOW(), t.updated_at) >= 7
```

## 自動完成 Cron Job 設置

生產環境建議設置 cron job 每小時執行一次：

```bash
# 編輯 crontab
crontab -e

# 添加以下行（每小時執行一次）
0 * * * * /usr/bin/php /path/to/backend/cron/auto_complete_tasks.php

# 或每 10 分鐘執行一次（更及時）
*/10 * * * * /usr/bin/php /path/to/backend/cron/auto_complete_tasks.php
```

---

**測試重點**：
1. 🕐 倒數計時器顯示正確
2. 👑 管理員權限檢查正確
3. ⚡ Time Up 按鈕功能正常
4. 🤖 自動完成邏輯正確
5. 💰 點數轉移機制正常
