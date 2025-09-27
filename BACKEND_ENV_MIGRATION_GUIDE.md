# Backend .env 檔案遷移指南

## 📋 問題說明

原本 `backend/.env` 使用符號連結指向 `../env/production.env`，這在 cPanel 部署時會導致以下問題：
- cPanel 可能不支援符號連結
- 跨目錄連結可能因權限問題失效
- 上傳時符號連結會破損

## ✅ 解決方案

### 1. 移除符號連結，使用直接檔案

```bash
# 備份原始連結（已完成）
ls -la backend/.env  # 原本: lrwxr-xr-x backend/.env -> ../env/production.env

# 創建實體 .env 檔案（已完成）
cp backend/.env.production backend/.env
```

### 2. 檔案結構變更

#### **變更前**：
```
backend/.env -> ../env/production.env  (符號連結)
backend/.env.production                (實體檔案)
```

#### **變更後**：
```
backend/.env                          (實體檔案，來自 .env.production)
backend/.env.production               (保留作為備份)
```

### 3. EnvLoader 載入順序

`backend/config/env_loader.php` 的載入優先順序：
1. 開發環境：`../env/development.env` (MAMP 檢測)
2. 生產環境：`../env/production.env` (自動檢測)
3. **回退檔案**：`backend/.env` ⭐ **現在使用此檔案**

## 🚀 部署到 cPanel

### 上傳檔案
```bash
# 確保上傳以下檔案到 cPanel 的 backend/ 目錄：
backend/.env                    # 主要配置檔案
backend/.env.production         # 備份檔案
backend/config/env_loader.php   # 載入器
```

### 驗證配置
在 cPanel 上執行測試：
```php
<?php
require_once 'config/env_loader.php';
try {
    EnvLoader::load();
    echo 'DB_HOST: ' . EnvLoader::get('DB_HOST') . "\n";
    echo 'APP_ENVIRONMENT: ' . EnvLoader::get('APP_ENVIRONMENT') . "\n";
} catch (Exception $e) {
    echo 'Error: ' . $e->getMessage() . "\n";
}
?>
```

## 📊 配置內容

### 主要環境變數
- `APP_ENVIRONMENT=production`
- `DB_HOST=localhost`
- `DB_NAME=hero4helpdemofhs_hero4help`
- `API_BASE_URL=https://hero4help.demofhs.com/backend`
- `IMAGE_BASE_URL=https://hero4help.demofhs.com`

### 安全注意事項
- `.env` 檔案包含敏感資訊（資料庫密碼、JWT 密鑰）
- 確保 `.htaccess` 阻止直接訪問 `.env` 檔案
- 定期更新密鑰和密碼

## 🔧 維護指南

### 更新配置
1. 修改 `backend/.env`
2. 同步更新 `backend/.env.production`（作為備份）
3. 如需要，同步更新 `env/production.env`

### 回滾方案
如果需要回滾到符號連結模式：
```bash
rm backend/.env
ln -s ../env/production.env backend/.env
```

## ✅ 測試結果

- ✅ EnvLoader 可正常載入 `backend/.env`
- ✅ 環境變數正確讀取
- ✅ cPanel 兼容性問題已解決
- ✅ 配置內容與原始檔案一致

## 📝 注意事項

1. **不要**將 `.env` 檔案提交到版本控制
2. 部署時確保 `.env` 檔案權限設為 `644` 或 `600`
3. 定期備份 `.env` 配置
4. 測試環境變數載入是否正常
