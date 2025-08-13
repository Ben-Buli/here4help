# 環境變數配置指南

> 本指南將協助您完成 Here4Help 專案的敏感資訊配置

---

## 🎯 目標

將硬編碼的敏感資訊（資料庫密碼、API 金鑰等）遷移到 `.env` 檔案，提升安全性。

---

## ✅ 已完成的自動化設定

1. **環境檔案建立**：`.env` 檔案已從範本複製
2. **PHP 載入器**：`backend/config/env_loader.php` 已建立
3. **資料庫配置**：`backend/config/database.php` 已更新使用環境變數
4. **Node.js 設定**：`backend/socket/server.js` 已安裝並配置 dotenv
5. **安全設定**：`.env` 已加入 `.gitignore`

---

## 🔧 需要手動完成的步驟

### 步驟 1: 編輯 .env 檔案

請開啟根目錄的 `.env` 檔案，確認以下重要配置：

```bash
# 開啟 .env 檔案
open .env
# 或使用您偏好的編輯器
code .env
```

**重要配置項目**：

#### 資料庫配置（開發環境）
```ini
DB_HOST=localhost
DB_PORT=8889
DB_NAME=hero4helpdemofhs_hero4help
DB_USERNAME=root
DB_PASSWORD=root  # 請確認您的 MAMP 密碼
```

#### 生產環境資料庫（部署時使用）
```ini
PROD_DB_HOST=your_production_host
PROD_DB_NAME=hero4helpdemofhs_hero4help_prod
PROD_DB_USERNAME=your_prod_username
PROD_DB_PASSWORD=your_secure_production_password
```

#### JWT 安全金鑰
```ini
JWT_SECRET=your_super_secure_jwt_secret_key_here_please_change_this
```

### 步驟 2: 測試配置

執行測試腳本確認配置正確：

```bash
cd backend/config
php test_env.php
```

**預期輸出**：
```
=== Here4Help 環境變數配置測試 ===

✅ 環境變數載入成功

📋 基本配置:
APP_ENV: development
APP_DEBUG: true

📋 資料庫配置:
Host: localhost
Port: 8889
Database: hero4helpdemofhs_hero4help
Username: root
Password: 已設定 (4 字元)
Charset: utf8mb4

🔗 測試資料庫連線...
✅ 資料庫連線成功!
```

### 步驟 3: 測試 Socket.IO 服務

```bash
cd backend/socket
npm start
```

**預期輸出**：
```
Socket.IO server running on port 3001
Database connected successfully
```

---

## 🚨 故障排除

### 問題 1: 資料庫連線失敗

**可能原因**：
- MAMP 服務未啟動
- 資料庫名稱不正確
- 連接埠號錯誤

**解決方案**：
1. 確認 MAMP 已啟動且 MySQL 運行在 8889 端口
2. 檢查資料庫名稱是否為 `hero4helpdemofhs_hero4help`
3. 確認用戶名密碼是否正確

### 問題 2: .env 檔案載入失敗

**可能原因**：
- .env 檔案位置錯誤
- 檔案權限問題
- 語法錯誤

**解決方案**：
1. 確認 .env 位於專案根目錄 `/Users/eliasscott/here4help/.env`
2. 檢查檔案權限：`ls -la .env`
3. 確認檔案格式：`KEY=value`，無空格

### 問題 3: Socket.IO 無法啟動

**可能原因**：
- dotenv 套件未安裝
- 端口被佔用
- 環境變數路徑錯誤

**解決方案**：
1. 重新安裝依賴：`cd backend/socket && npm install`
2. 檢查端口：`lsof -i :3001`
3. 確認 .env 路徑正確

---

## 📋 配置檢查清單

### ✅ 安全性檢查
- [ ] `.env` 檔案已加入 `.gitignore`
- [ ] JWT_SECRET 已設定為強密碼
- [ ] 生產環境密碼已設定為強密碼
- [ ] 檔案權限適當 (644 或 600)

### ✅ 功能性檢查
- [ ] PHP 環境變數載入測試通過
- [ ] 資料庫連線測試成功
- [ ] Socket.IO 服務啟動正常
- [ ] 所有 API 端點正常運作

### ✅ 開發環境檢查
- [ ] MAMP MySQL 連線正常
- [ ] 本地開發 URL 配置正確
- [ ] Debug 模式已啟用

---

## 🎉 完成確認

當所有測試通過後，您已成功完成環境變數配置！

**下一步建議**：
1. 測試現有功能確保一切正常
2. 清理專案中的不必要檔案
3. 進行任務狀態管理優化

---

## 📞 需要協助？

如遇到問題，請檢查：
1. 測試腳本輸出的錯誤訊息
2. MAMP 服務狀態
3. .env 檔案格式和內容

記住：敏感資訊安全是專案成功的基石！🔐