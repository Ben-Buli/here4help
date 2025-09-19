# Here4Help 部署檢查清單

> 完整的生產環境部署步驟和檢查項目

## 🚀 部署前準備

### ✅ 環境配置檢查
- [ ] 執行 `./create_production_env.sh` 創建生產環境配置
- [ ] 更新 `backend/.env` 資料庫連接資訊
- [ ] 更新 `admin/.env` Laravel APP_KEY
- [ ] 設定 Email SMTP 配置
- [ ] 確認所有 OAuth 憑證正確

### ✅ 第三方服務準備
- [ ] Google Cloud Console 新增生產環境回調 URL
- [ ] Facebook Developer 更新應用域名
- [ ] Apple Developer 確認 Service ID 配置
- [ ] cPanel 主機帳號準備就緒
- [ ] SSL 憑證準備 (Let's Encrypt 或購買)

## 🔧 後端部署 (Backend PHP API)

### ✅ 檔案上傳
- [ ] 壓縮 backend 目錄: `tar -czf backend.tar.gz backend/`
- [ ] 上傳到 cPanel 文件管理器
- [ ] 解壓到 `public_html/backend/`
- [ ] 確認目錄結構正確

### ✅ 資料庫設定
- [ ] 在 cPanel 創建 MySQL 資料庫
- [ ] 創建資料庫用戶並分配權限
- [ ] 匯出本地資料庫: `mysqldump -u root -p hero4helpdemofhs_hero4help > database_backup.sql`
- [ ] 在 cPanel phpMyAdmin 匯入資料庫
- [ ] 更新 `backend/.env` 資料庫配置

### ✅ 檔案權限設定
```bash
chmod 755 backend/
chmod 644 backend/.env
chmod -R 755 backend/uploads/
chmod -R 755 backend/storage/
chmod 644 backend/.htaccess
```

### ✅ 功能測試
- [ ] 測試 API 基本連通性: `https://hero4help.demofhs.com/backend/api/system/health.php`
- [ ] 測試資料庫連接
- [ ] 測試檔案上傳功能
- [ ] 測試 JWT Token 生成

## 👨‍💼 管理員後台部署 (Laravel Admin)

### ✅ Laravel 後端部署
- [ ] 壓縮 admin 目錄: `tar -czf admin.tar.gz admin/`
- [ ] 上傳到 cPanel 並解壓到 `public_html/admin/`
- [ ] 在 cPanel 終端執行:
  ```bash
  cd public_html/admin
  composer install --no-dev --optimize-autoloader
  php artisan key:generate
  php artisan migrate
  php artisan config:cache
  php artisan route:cache
  ```

### ✅ Admin Frontend 建置
- [ ] 本地建置前端: `cd admin/frontend && npm run build`
- [ ] 上傳 `dist/` 目錄內容到 `public_html/admin/public/`
- [ ] 設定 Apache 指向 `admin/public`

### ✅ 權限設定
```bash
chmod -R 755 admin/storage/
chmod -R 755 admin/bootstrap/cache/
chmod 600 admin/.env
```

### ✅ 功能測試
- [ ] 管理員登入功能
- [ ] Sanctum API Token 生成
- [ ] 前端頁面載入正常
- [ ] API 與後端通信正常

## 🔌 Socket 服務部署

### ✅ 檢查 cPanel Node.js 支援
- [ ] 確認 cPanel 是否支援 Node.js App
- [ ] 如支援，在 cPanel 中創建 Node.js 應用
- [ ] 設定應用根目錄: `backend/socket`
- [ ] 設定啟動文件: `server.js`
- [ ] 設定環境: Production

### ✅ 替代方案 (如 cPanel 不支援)
- [ ] 考慮使用 Railway/Heroku 部署 Socket 服務
- [ ] 或實施長輪詢備用方案
- [ ] 更新前端 Socket URL 配置

## 📱 移動應用打包

### ✅ Android APK 打包
- [ ] 確認簽名密鑰已準備
- [ ] 執行建置指令:
  ```bash
  flutter build apk --release \
    --dart-define=ENVIRONMENT=production \
    --dart-define=API_BASE_URL=https://hero4help.demofhs.com/backend \
    --dart-define=SOCKET_URL=https://hero4help.demofhs.com:3001 \
    --dart-define=DEBUG_MODE=false
  ```
- [ ] 測試 APK 安裝和基本功能
- [ ] 準備 Google Play Store 上架資料

### ✅ iOS TestFlight 打包
- [ ] 確認 Apple Developer 帳號和憑證
- [ ] 執行建置指令:
  ```bash
  flutter build ios --release \
    --dart-define=ENVIRONMENT=testflight \
    --dart-define=API_BASE_URL=https://hero4help.demofhs.com/backend \
    --dart-define=SOCKET_URL=https://hero4help.demofhs.com:3001 \
    --dart-define=DEBUG_MODE=false
  ```
- [ ] 在 Xcode 中 Archive
- [ ] 上傳到 App Store Connect
- [ ] 設定 TestFlight 測試人員

## 🔒 安全性設定

### ✅ SSL 憑證
- [ ] 在 cPanel 啟用 SSL 憑證 (Let's Encrypt 或購買)
- [ ] 確認 HTTPS 重定向正常
- [ ] 測試所有 HTTPS 端點

### ✅ 安全配置
- [ ] 確認 `.env` 文件不可公開訪問
- [ ] 設定適當的 CORS 政策
- [ ] 啟用 Rate Limiting
- [ ] 確認敏感目錄受保護

## 🧪 功能測試

### ✅ 基本功能測試
- [ ] 用戶註冊和登入
- [ ] 第三方登入 (Google/Facebook/Apple)
- [ ] 任務發布和應徵
- [ ] 聊天功能
- [ ] 檔案上傳
- [ ] 管理員後台功能

### ✅ 整合測試
- [ ] 前端與後端 API 通信
- [ ] Socket 即時通信 (如已部署)
- [ ] 第三方服務整合
- [ ] 支付功能 (如已啟用)

### ✅ 效能測試
- [ ] API 響應時間 < 2秒
- [ ] 頁面載入時間 < 3秒
- [ ] 資料庫查詢效能
- [ ] 檔案上傳速度

## 📊 監控和維護

### ✅ 監控設定
- [ ] 設定錯誤日誌監控
- [ ] 配置效能監控
- [ ] 設定備份策略
- [ ] 建立維護計劃

### ✅ 文檔更新
- [ ] 更新部署文檔
- [ ] 記錄配置變更
- [ ] 準備用戶手冊
- [ ] 建立故障排除指南

## 🚨 緊急回滾準備

### ✅ 備份策略
- [ ] 資料庫完整備份
- [ ] 檔案系統備份
- [ ] 配置文件備份
- [ ] 測試回滾程序

### ✅ 回滾觸發條件
- [ ] 嚴重安全漏洞
- [ ] 資料遺失風險
- [ ] 核心功能無法使用
- [ ] 用戶大量投訴

## ✅ 部署完成確認

### ✅ 最終檢查
- [ ] 所有功能測試通過
- [ ] 效能指標達標
- [ ] 安全性檢查通過
- [ ] 監控系統正常運作
- [ ] 用戶可以正常使用所有功能

### ✅ 上線準備
- [ ] 通知相關人員部署完成
- [ ] 更新 DNS 記錄 (如需要)
- [ ] 發布更新公告
- [ ] 準備技術支援

---

## 📞 聯絡資訊

**部署負責人**: _________________  
**部署日期**: _________________  
**部署版本**: 1.2.4+20250118  
**部署狀態**: _________________

## 🔗 相關文檔

- [環境配置指南](ENV_CONFIGURATION_GUIDE.md)
- [生產環境配置](PRODUCTION_ENV_FILES.md)
- [部署腳本](create_production_env.sh)
- [故障排除指南](docs/TROUBLESHOOTING.md)
