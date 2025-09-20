# PHP 8.4 升級指南

## 📋 升級前準備

### 1. 備份完成 ✅
- **/backend 備份位置**: `backend_backup_0919_before_updateToPHP8.4/`
- **/admin 備份位置**: `admin_0919_before_updateToPHP8.4/`
- **備份時間**: 2024-09-19
- **備份方式**: rsync (排除符號連結問題)

### 2. 相容性評估結果

#### `/backend` 目錄
- **相容性等級**: ✅ 高（幾乎無痛部署）
- **風險等級**: 🟢 低
- **主要優勢**:
  - 使用現代 PHP 語法
  - 無舊版函數依賴
  - 使用 PDO 資料庫層
  - 現代錯誤處理機制

#### `/admin` 目錄
- **相容性等級**: ⚠️ 中等（需要升級 Laravel）
- **風險等級**: 🟡 中等
- **主要問題**: Laravel 9 不支援 PHP 8.4
- **解決方案**: 升級至 Laravel 11
- **現狀**: Laravel 9.52.20, PHP ^8.2
- **相容性配置**: 已準備 `php84_compatibility.php`

## 🚀 升級步驟

### 第一階段：/backend 升級（推薦先執行）

#### 1. 添加相容性配置
```bash
# 相容性配置檔案已創建
backend/config/php84_compatibility.php
```

#### 2. 在主要入口檔案載入相容性配置
```php
// 在 backend/index.php 或主要 API 檔案開頭添加：
require_once __DIR__ . '/config/php84_compatibility.php';
```

#### 3. 更新錯誤處理設定
```php
// 舊版設定
error_reporting(E_ALL);
ini_set('display_errors', 1);

// 新版設定（避免 Deprecated 警告）
error_reporting(E_ALL & ~E_DEPRECATED);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
```

#### 4. 測試部署
```bash
# 在 cPanel 中設置 PHP 8.4
# 運行部署檢查
php backend/scripts/deployment_check.php
```

### 第二階段：/admin 升級（需要 Laravel 升級）

#### 1. 升級 Laravel 框架
```bash
cd admin
composer update laravel/framework
```

#### 2. 更新 composer.json
```json
{
  "require": {
    "php": "^8.4",
    "laravel/framework": "^11.0"
  }
}
```

#### 3. 配置調整
- 檢查 Laravel 11 的 breaking changes
- 更新路由和控制器
- 調整配置檔案

## 🔍 相容性檢查清單

### ✅ /backend 檢查項目
- [x] 無舊版 MySQL 函數 (`mysql_*`, `mysqli_*`)
- [x] 無棄用函數 (`create_function`, `each()`, `split()`)
- [x] 使用現代 PDO 資料庫層
- [x] 現代 PHP 語法 (命名空間、類別、try-catch)
- [x] 現代字串函數 (`str_contains`, `str_starts_with`)
- [x] 相容性配置檔案已準備
- [x] 部署檢查腳本已更新

### ⚠️ /admin 檢查項目
- [x] 相容性配置檔案已準備
- [ ] Laravel 框架升級至 11.x
- [ ] Composer 依賴更新
- [ ] 配置檔案調整
- [ ] 功能測試

## 🛡️ 風險評估

### 🟢 低風險項目
- **資料庫操作**: PDO 完全相容
- **API 架構**: RESTful 設計相容
- **認證系統**: 自定義 JWT 相容
- **檔案處理**: 現代 PHP 語法相容

### 🟡 中等風險項目
- **錯誤處理**: 可能需要調整設定
- **擴展依賴**: 需要確認所有擴展可用
- **除錯功能**: 可能需要更新除錯設定

### 🔴 高風險項目
- **無**: 專案使用現代 PHP 語法，風險較低

## 📊 升級時間估算

### /backend 升級
- **準備階段**: 1 天
- **測試階段**: 1-2 天
- **部署階段**: 1 天
- **總計**: 3-4 天

### /admin 升級
- **Laravel 升級**: 1-2 週
- **測試階段**: 1 週
- **部署階段**: 1 週
- **總計**: 3-4 週

## 🎯 最終建議

### ✅ 立即執行
1. **/backend 的 PHP 8.4 升級**（風險低，收益高）
2. **性能提升**：PHP 8.4 有顯著性能改進
3. **安全性**：獲得最新的安全修復

### 📅 計劃執行
1. **/admin 的 Laravel 11 升級**（需要充分測試）
2. **分階段實施**：避免同時影響兩個系統

### 🔄 回滾計劃
1. **快速回滾**: 使用備份 `backend_backup_0919_before_updateToPHP8.4/`
2. **監控運行**: 升級後密切監控系統穩定性
3. **問題處理**: 準備快速修復方案

## 📞 支援資源

- **PHP 8.4 官方文件**: https://www.php.net/releases/8.4/
- **Laravel 11 升級指南**: https://laravel.com/docs/11.x/upgrade
- **部署檢查腳本**: `backend/scripts/deployment_check.php`
- **相容性配置**: `backend/config/php84_compatibility.php`

---

**升級完成後，請更新此文件記錄實際執行結果和遇到的問題。**
