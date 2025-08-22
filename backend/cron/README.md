# Cron 排程設定指南

## 自動完成任務排程

### 功能說明
`auto_complete_tasks.php` 腳本會自動檢查所有處於 `pending_confirmation` 狀態超過7天的任務，並將其標記為 `completed`。

### 設定 Cron Job

#### 1. 編輯 crontab
```bash
crontab -e
```

#### 2. 添加排程規則
```bash
# 每小時執行一次自動完成檢查
0 * * * * /usr/bin/php /path/to/here4help/backend/cron/auto_complete_tasks.php >> /path/to/here4help/backend/logs/cron.log 2>&1

# 或者每天凌晨2點執行一次
0 2 * * * /usr/bin/php /path/to/here4help/backend/cron/auto_complete_tasks.php >> /path/to/here4help/backend/logs/cron.log 2>&1
```

#### 3. 本地開發環境 (MAMP)
```bash
# 使用 MAMP 的 PHP
0 * * * * /Applications/MAMP/bin/php/php8.2.0/bin/php /Users/eliasscott/here4help/backend/cron/auto_complete_tasks.php >> /Users/eliasscott/here4help/backend/logs/cron.log 2>&1
```

### 手動執行測試
```bash
# 進入專案目錄
cd /Users/eliasscott/here4help

# 手動執行腳本
php backend/cron/auto_complete_tasks.php
```

### 日誌檔案
- **執行日誌**: `backend/logs/auto_complete_YYYY-MM.log`
- **Cron 日誌**: `backend/logs/cron.log`

### 監控與維護
1. **檢查日誌**: 定期檢查日誌檔案確保腳本正常執行
2. **錯誤處理**: 腳本會記錄所有錯誤並繼續執行
3. **日誌清理**: 自動保留最近3個月的日誌檔案

### 安全注意事項
1. 確保腳本檔案權限正確 (`chmod 755`)
2. 確保日誌目錄可寫入 (`chmod 755 backend/logs/`)
3. 定期檢查資料庫連線狀態

### 故障排除
1. **權限問題**: 檢查檔案和目錄權限
2. **資料庫連線**: 確認資料庫設定正確
3. **PHP 路徑**: 確認 cron 中的 PHP 路徑正確
4. **時區設定**: 確認伺服器時區設定正確

