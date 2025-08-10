# 資料庫管理工具

這套工具提供了完整的資料庫結構驗證、修復和報告生成功能。

## 📁 檔案結構

```
backend/database/
├── validate_structure.php    # 資料庫結構驗證腳本
├── fix_structure.php         # 資料庫結構修復腳本
├── generate_report.php       # 結構報告生成器
├── database_manager.php      # 主控腳本（整合所有功能）
├── migrations/               # 資料庫遷移檔案
├── reports/                  # 生成的報告檔案
├── backups/                  # 結構備份檔案
└── README.md                 # 本說明文件
```

## 🚀 快速開始

### 1. 使用主控腳本（推薦）

```bash
cd backend/database
php database_manager.php
```

主控腳本提供以下功能：
- 驗證資料庫結構
- 修復資料庫結構
- 生成結構報告
- 完整檢查和修復
- 查看資料庫狀態
- 備份資料庫結構

### 2. 單獨執行各功能

#### 驗證資料庫結構
```bash
php validate_structure.php
```

#### 修復資料庫結構
```bash
php fix_structure.php
```

#### 生成結構報告
```bash
php generate_report.php
```

## 📋 功能詳解

### 1. 資料庫結構驗證

驗證腳本會檢查以下項目：

#### 核心表格檢查
- **users 表格**: 檢查必要欄位（id, username, email, password, created_at）
- **tasks 表格**: 檢查必要欄位（id, title, description, creator_id, status_id, created_at）
- **task_statuses 表格**: 檢查表格存在性和預設狀態資料
- **chat_rooms 表格**: 檢查聊天室表格結構
- **chat_messages 表格**: 檢查訊息表格結構和必要欄位
- **chat_reads 表格**: 檢查已讀狀態表格
- **task_applications 表格**: 檢查申請表格結構

#### 外鍵關係檢查
- 檢查所有外鍵約束是否正確設置
- 驗證參考完整性

#### 索引檢查
- 檢查重要欄位的索引是否存在
- 驗證索引類型（唯一索引、普通索引）

### 2. 資料庫結構修復

修復腳本會自動處理以下問題：

#### 表格創建
- 如果表格不存在，自動創建標準結構
- 包含所有必要的欄位和約束

#### 欄位添加
- 檢查並添加缺少的欄位
- 設置正確的資料類型和預設值

#### 預設資料插入
- 為 task_statuses 表格插入預設狀態
- 確保系統有基本的狀態資料

#### 索引創建
- 為常用查詢欄位創建索引
- 提升查詢效能

### 3. 結構報告生成

報告包含以下資訊：

#### 資料庫概覽
- 資料庫名稱和大小
- 表格數量統計
- 生成時間

#### 詳細表格資訊
- 每個表格的完整結構
- 欄位類型、約束和註解
- 記錄數統計

#### 關係圖
- 外鍵關係列表
- 更新和刪除規則

#### 索引資訊
- 所有索引的詳細資訊
- 索引類型和基數

## 🔧 配置說明

### 資料庫連線配置

工具使用 `../config/database.php` 中的配置：

```php
// 開發環境配置
'development' => [
    'host' => 'localhost',
    'port' => '8889',
    'dbname' => 'hero4helpdemofhs_hero4help',
    'username' => 'root',
    'password' => 'root',
    'charset' => 'utf8mb4'
]
```

### 環境判斷

工具會自動判斷環境：
- `localhost:8888` 或 `127.0.0.1:8888` → 開發環境
- 其他 → 生產環境

## 📊 報告格式

### JSON 報告
- 位置：`backend/database/reports/database_structure_YYYY-MM-DD_HH-MM-SS.json`
- 包含完整的結構資訊，適合程式處理

### HTML 報告
- 位置：`backend/database/reports/database_structure_YYYY-MM-DD_HH-MM-SS.html`
- 美觀的視覺化報告，適合瀏覽器查看

## ⚠️ 注意事項

### 安全提醒
1. **備份資料庫**: 執行修復前務必備份資料庫
2. **測試環境**: 建議先在測試環境執行
3. **權限檢查**: 確保資料庫用戶有足夠權限

### 修復限制
1. **資料類型變更**: 不會自動變更現有欄位的資料類型
2. **外鍵修復**: 複雜的外鍵問題需要手動處理
3. **資料遷移**: 不會自動遷移現有資料

## 🐛 故障排除

### 常見錯誤

#### 連線失敗
```
Database connection failed: SQLSTATE[HY000] [2002] Connection refused
```
**解決方案**: 檢查資料庫服務是否啟動，確認連線配置

#### 權限不足
```
Access denied for user 'root'@'localhost'
```
**解決方案**: 檢查資料庫用戶權限，確認密碼正確

#### 表格不存在
```
Table 'xxx' doesn't exist
```
**解決方案**: 執行修復腳本創建缺少的表格

### 日誌查看

所有操作都會在控制台輸出詳細日誌，包括：
- 執行的 SQL 語句
- 發現的問題
- 修復的項目
- 錯誤訊息

## 📈 效能優化

### 索引建議
工具會自動為以下欄位創建索引：
- `users.username` 和 `users.email` (唯一索引)
- `tasks.creator_id` 和 `tasks.status_id`
- `chat_messages.room_id` 和 `chat_messages.created_at`
- `task_applications.task_id` 和 `task_applications.applicant_id`

### 查詢優化
- 使用適當的資料類型
- 設置正確的外鍵約束
- 定期更新統計資訊

## 🔄 定期維護

建議定期執行以下操作：

1. **每日**: 查看資料庫狀態
2. **每週**: 驗證資料庫結構
3. **每月**: 生成完整報告
4. **部署前**: 執行完整檢查和修復

## 📞 支援

如果遇到問題，請：
1. 查看控制台錯誤訊息
2. 檢查資料庫連線配置
3. 確認資料庫用戶權限
4. 查看生成的報告檔案

---

**版本**: 1.0.0  
**更新日期**: 2025-01-10  
**維護者**: Here4Help 開發團隊 