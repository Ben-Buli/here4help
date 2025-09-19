# Here4Help Backend cPanel 部署指南

## 📋 部署概覽

- **目標環境**: hero4help.demofhs.com/backend
- **部署檔案**: `backend_cpanel_deploy_20250917_031831.tar.gz`
- **檔案大小**: 84M
- **PHP 版本要求**: 8.0+

## 🚀 部署步驟

### 步驟 1: 上傳檔案到 cPanel

1. **登入 cPanel**
   - 訪問: https://hero4help.demofhs.com:2083
   - 使用您的 cPanel 帳號登入

2. **上傳壓縮檔**
   - 進入「檔案管理器」
   - 導航到 `public_html/backend` 目錄
   - 上傳 `backend_cpanel_deploy_20250917_031831.tar.gz`

### 步驟 2: 解壓和設定目錄結構

1. **解壓檔案**
   ```bash
   # 在 cPanel 檔案管理器中
   cd public_html/backend/
   tar -xzf backend_cpanel_deploy_20250917_031831.tar.gz
   ```

2. **建立目錄結構**
   ```bash
   # 確保目錄結構正確
   public_html/
   ├── backend/           # Backend API 目錄
   │   ├── api/          # API 端點
   │   ├── config/       # 配置檔案
   │   ├── logs/         # 日誌目錄
   │   ├── .env          # 環境配置
   │   └── .htaccess     # Apache 配置
   ```

### 步驟 3: 設定檔案權限

1. **設定目錄權限 (755)**
   ```bash
   chmod 755 public_html/backend/
   chmod 755 public_html/backend/api/
   chmod 755 public_html/backend/config/
   chmod 755 public_html/backend/logs/
   chmod 755 public_html/backend/uploads/
   ```

2. **設定檔案權限 (644)**
   ```bash
   chmod 644 public_html/backend/.env
   chmod 644 public_html/backend/.htaccess
   chmod 644 public_html/backend/api/*.php
   chmod 644 public_html/backend/config/*.php
   ```

3. **設定日誌檔案權限 (666)**
   ```bash
   chmod 666 public_html/backend/logs/error.log
   ```

### 步驟 4: 驗證 PHP 版本

1. **檢查 PHP 版本**
   - 在 cPanel 中進入「PHP 版本選擇器」
   - 確保選擇 PHP 8.0 或更高版本
   - 建議使用 PHP 8.1 或 8.2

2. **檢查 PHP 擴展**
   確保以下 PHP 擴展已啟用：
   - `pdo_mysql`
   - `json`
   - `curl`
   - `openssl`
   - `mbstring`

### 步驟 5: 資料庫設定

1. **確認資料庫連線**
   - 資料庫主機: `localhost`
   - 資料庫名稱: `hero4helpdemofhs_hero4help`
   - 用戶名: `hero4helpdemofhs_hero`
   - 密碼: `Ffb#Vh$2N22p`
   - 端口: `3306`

2. **測試資料庫連線**
   ```bash
   # 在 cPanel 中建立測試檔案
   echo "<?php phpinfo(); ?>" > public_html/backend/test_db.php
   ```

## 🧪 測試部署

### 測試 1: API Ping 端點

```bash
# 測試基本 API 功能
curl -X GET https://hero4help.demofhs.com/backend/api/ping
```

**預期回應**:
```json
{
  "pong": true,
  "timestamp": "2025-09-17T03:18:31Z",
  "environment": "production"
}
```

### 測試 2: 資料庫連線

```bash
# 測試資料庫連線
curl -X GET https://hero4help.demofhs.com/backend/api/test-db
```

### 測試 3: 認證端點

```bash
# 測試登入端點 (不需要認證)
curl -X POST https://hero4help.demofhs.com/backend/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'
```

## 🔧 故障排除

### 常見問題 1: 500 內部伺服器錯誤

**可能原因**:
- PHP 版本不正確
- 檔案權限問題
- 資料庫連線失敗

**解決方法**:
1. 檢查 PHP 版本
2. 檢查檔案權限
3. 檢查錯誤日誌: `public_html/backend/logs/error.log`

### 常見問題 2: 404 找不到檔案

**可能原因**:
- .htaccess 配置問題
- 檔案路徑錯誤

**解決方法**:
1. 檢查 .htaccess 檔案是否存在
2. 檢查 Apache mod_rewrite 是否啟用
3. 檢查檔案路徑是否正確

### 常見問題 3: 資料庫連線失敗

**可能原因**:
- 資料庫憑證錯誤
- 資料庫服務未啟動

**解決方法**:
1. 檢查資料庫憑證
2. 在 cPanel 中測試資料庫連線
3. 檢查資料庫服務狀態

## 📊 監控和維護

### 日誌監控

1. **錯誤日誌**
   ```bash
   tail -f public_html/backend/logs/error.log
   ```

2. **Apache 錯誤日誌**
   ```bash
   tail -f /var/log/apache2/error.log
   ```

### 效能監控

1. **API 回應時間**
   ```bash
   curl -w "@curl-format.txt" -o /dev/null -s https://hero4help.demofhs.com/backend/api/ping
   ```

2. **資料庫連線狀態**
   ```bash
   # 在 cPanel 中檢查資料庫狀態
   ```

## 🔒 安全檢查清單

- [ ] .env 檔案權限設定為 644
- [ ] 敏感檔案已隱藏
- [ ] CORS 設定正確
- [ ] 安全標頭已設定
- [ ] 錯誤報告已關閉
- [ ] 日誌記錄已啟用

## 📞 支援

如果遇到問題，請檢查：

1. **錯誤日誌**: `public_html/backend/logs/error.log`
2. **cPanel 錯誤日誌**: cPanel > 錯誤日誌
3. **資料庫狀態**: cPanel > MySQL 資料庫

## 🎯 部署完成檢查清單

- [ ] 檔案已上傳到正確目錄
- [ ] 檔案權限已設定正確
- [ ] PHP 版本已設定正確
- [ ] 資料庫連線正常
- [ ] API 端點可正常訪問
- [ ] 錯誤日誌正常記錄
- [ ] 安全設定已啟用

---

**部署完成時間**: 2025-09-17 03:18:31  
**部署版本**: Backend API v1.0  
**部署環境**: hero4help.demofhs.com/backend
