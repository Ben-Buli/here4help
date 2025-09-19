# CPanel Flutter Web 部署修復指南

## 🚨 問題診斷

### 當前問題
- JavaScript 檔案返回 HTML 內容 (MIME 類型錯誤)
- manifest.json 語法錯誤
- Facebook SDK 配置問題
- 所有靜態資源都被重導到 index.html

### 根本原因
**Flutter Web 建置檔案沒有正確部署到 CPanel**

---

## 🛠️ 修復步驟

### 步驟 1: 重新建置 Flutter Web

```bash
# 清理舊的建置檔案
flutter clean

# 重新建置 Flutter Web (生產環境)
flutter build web --release --dart-define=ENVIRONMENT=production

# 檢查建置結果
ls -la build/web/
```

### 步驟 2: 準備部署檔案

```bash
# 進入建置目錄
cd build/web/

# 檢查檔案內容
ls -la
# 應該看到: index.html, main.dart.js, flutter_bootstrap.js, assets/, icons/, manifest.json

# 建立部署壓縮檔
tar -czf flutter_web_deploy.tar.gz *
```

### 步驟 3: CPanel 檔案結構修復

#### 3.1 登入 CPanel
- 訪問: https://hero4help.demofhs.com:2083
- 使用您的 CPanel 帳號登入

#### 3.2 檢查當前檔案結構
在 CPanel 文件管理器中檢查：
```
public_html/
├── frontend/          # 這裡應該是 Flutter Web 檔案
│   ├── index.html     # ❌ 目前返回錯誤內容
│   ├── main.dart.js    # ❌ 目前返回 HTML
│   ├── flutter_bootstrap.js  # ❌ 目前返回 HTML
│   ├── manifest.json   # ❌ 目前返回 HTML
│   ├── assets/         # ❌ 目錄可能不存在
│   └── icons/          # ❌ 目錄可能不存在
```

#### 3.3 重新部署 Flutter Web 檔案

**方法 A: 使用 CPanel 文件管理器**
1. 導航到 `public_html/frontend/`
2. 刪除所有現有檔案
3. 上傳 `flutter_web_deploy.tar.gz`
4. 解壓縮檔案

**方法 B: 使用 FTP/SFTP**
```bash
# 使用 FTP 客戶端上傳檔案
# 目標路徑: /public_html/frontend/
```

### 步驟 4: 驗證檔案部署

#### 4.1 檢查檔案內容
```bash
# 測試 JavaScript 檔案
curl https://hero4help.demofhs.com/frontend/flutter_bootstrap.js | head -5
# 預期: 應該看到 JavaScript 程式碼，不是 HTML

# 測試 manifest.json
curl https://hero4help.demofhs.com/frontend/manifest.json
# 預期: 應該看到 JSON 格式的 manifest

# 測試主頁面
curl https://hero4help.demofhs.com/frontend/index.html | head -10
# 預期: 應該看到正確的 HTML 內容
```

#### 4.2 檢查 MIME 類型
```bash
# 檢查 JavaScript 檔案的 MIME 類型
curl -I https://hero4help.demofhs.com/frontend/flutter_bootstrap.js
# 預期: content-type: application/javascript

# 檢查 manifest.json 的 MIME 類型
curl -I https://hero4help.demofhs.com/frontend/manifest.json
# 預期: content-type: application/json
```

### 步驟 5: 修復 Facebook SDK 配置

#### 5.1 檢查環境配置
在 `build/web/assets/env/.env.production` 中設定：
```bash
# Facebook OAuth 配置
FACEBOOK_APP_ID=您的實際Facebook App ID
FACEBOOK_CLIENT_TOKEN=您的實際Facebook Client Token
```

#### 5.2 重新建置並部署
```bash
# 重新建置包含正確的 Facebook 配置
flutter build web --release --dart-define=ENVIRONMENT=production

# 重新部署到 CPanel
```

---

## 🔍 故障排除

### 問題 1: JavaScript 檔案仍然返回 HTML
**解決方案**: 檢查 CPanel 的 `.htaccess` 配置
```apache
# 確保靜態檔案不被重寫
RewriteCond %{REQUEST_FILENAME} -f
RewriteRule ^(.*)$ - [L]
```

### 問題 2: manifest.json 語法錯誤
**解決方案**: 檢查 manifest.json 格式
```json
{
  "name": "Here4Help",
  "short_name": "Here4Help",
  "start_url": ".",
  "display": "standalone",
  "background_color": "#0175C2",
  "theme_color": "#0175C2",
  "description": "NCCU Social Task Posting APP",
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
```

### 問題 3: Facebook SDK 初始化失敗
**解決方案**: 檢查 Facebook App 配置
1. 確認 Facebook App ID 正確
2. 檢查 Facebook App 的授權域名設定
3. 確認 OAuth 回調 URL 正確

---

## ✅ 驗證清單

部署完成後，確認以下項目：

- [ ] `https://hero4help.demofhs.com/frontend/flutter_bootstrap.js` 返回 JavaScript 程式碼
- [ ] `https://hero4help.demofhs.com/frontend/manifest.json` 返回正確的 JSON
- [ ] `https://hero4help.demofhs.com/frontend/index.html` 載入 Flutter 應用程式
- [ ] 瀏覽器控制台無 MIME 類型錯誤
- [ ] Facebook SDK 初始化成功
- [ ] 應用程式正常載入和運行

---

## 📞 支援

如果問題持續存在，請檢查：
1. CPanel 檔案權限設定
2. Apache 模組是否啟用 (mod_rewrite, mod_headers)
3. PHP 版本和配置
4. 防火牆和安全設定
