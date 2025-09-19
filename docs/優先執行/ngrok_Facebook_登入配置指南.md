# ngrok Facebook 登入配置指南

> 本文件提供使用 ngrok 進行 Facebook 登入 Web 測試的完整配置說明。

---

## 🌐 **ngrok 簡介**

### **什麼是 ngrok？**
ngrok 是一個反向代理工具，可以將本地開發伺服器暴露到公網，讓您能夠：
- 在本地開發時測試 HTTPS 功能
- 讓外部服務（如 Facebook）能夠訪問您的本地開發環境
- 進行跨平台的第三方登入測試

### **為什麼需要 ngrok？**
- **Facebook 登入要求**：Facebook 要求回調 URL 必須是 HTTPS
- **本地開發限制**：localhost 無法提供 HTTPS 服務
- **跨平台測試**：可以在不同設備上測試您的應用程式

---

## 🚀 **ngrok 安裝與配置**

### **1. 安裝 ngrok**

#### **macOS (使用 Homebrew)**
```bash
brew install ngrok/ngrok/ngrok
```

#### **手動安裝**
1. 前往 [ngrok.com](https://ngrok.com)
2. 註冊免費帳號
3. 下載對應平台的版本
4. 解壓縮並將 ngrok 加入 PATH

### **2. 配置 ngrok 認證**

#### **獲取認證 Token**
1. 登入 [ngrok.com](https://ngrok.com)
2. 前往 Dashboard → Your Authtoken
3. 複製您的 authtoken

#### **設定認證**
```bash
ngrok config add-authtoken YOUR_AUTHTOKEN_HERE
```

---

## 🔧 **啟動 ngrok 隧道**

### **1. 啟動本地開發伺服器**

首先確保您的 Node.js 開發伺服器正在運行：

```bash
# 啟動 Node.js 伺服器
node server.js

# 伺服器應該在 localhost:3001 上運行
# 您應該看到類似這樣的輸出：
# Server running on port 3001
```

### **2. 啟動 ngrok 隧道**

#### **基本啟動命令**
```bash
# 將本地 3001 端口暴露到公網
ngrok http 3001
```

#### **指定子域名（推薦）**
```bash
# 使用固定的子域名（需要付費帳號）
ngrok http 3001 --subdomain=here4help-dev

# 或者使用隨機子域名（免費帳號）
ngrok http 3001
```

### **3. 獲取 ngrok 網址**

啟動成功後，您會看到類似這樣的輸出：

```
Session Status                online
Account                       your-email@example.com
Version                       3.x.x
Region                        United States (us)
Forwarding                    https://abc123.ngrok.io -> http://localhost:3001
```

**重要**：記下 `https://abc123.ngrok.io` 這個網址，這就是您的 ngrok 網址。

---

## 📱 **Facebook 開發者控制台配置**

### **1. 登入 Facebook 開發者控制台**
- 前往 [developers.facebook.com](https://developers.facebook.com)
- 選擇您的應用程式

### **2. 配置 OAuth 重新導向 URI**

#### **新增 ngrok 網址**
1. 在左側選單中選擇 `Facebook 登入` → `設定`
2. 找到 `有效的 OAuth 重新導向 URI` 區段
3. 點擊 `新增 URI`
4. 輸入您的 ngrok 網址：
   ```
   https://your-ngrok-url.ngrok.io/auth/facebook/callback
   ```

#### **同時保留本地網址**
為了方便開發，建議同時保留：
```
http://localhost:3001/auth/facebook/callback
https://your-ngrok-url.ngrok.io/auth/facebook/callback
```

### **3. 配置應用程式網域**

#### **新增 ngrok 網域**
1. 在 `設定` → `基本` 中
2. 找到 `應用程式網域` 區段
3. 新增您的 ngrok 網域（不含 https://）：
   ```
   your-ngrok-url.ngrok.io
   ```

---

## 🔄 **更新環境配置**

### **1. 更新 env.local**

將您的 ngrok 網址填入環境配置：

```bash
# 應用程式 URL
APP_URL=http://localhost:3001
APP_HTTPS_URL=https://your-ngrok-url.ngrok.io

# Facebook OAuth 2.0
FACEBOOK_REDIRECT_URI=https://your-ngrok-url.ngrok.io/auth/facebook/callback

# 回調 URL 配置
FACEBOOK_CALLBACK_URL=https://your-ngrok-url.ngrok.io/here4help/backend/api/auth/facebook/callback
```

### **2. 更新 Facebook 登入配置**

#### **在 Flutter 中更新配置**
如果您需要在 Flutter 中使用 ngrok 網址，可以更新相關配置：

```dart
// 在 PlatformAuthService 中
final String facebookCallbackUrl = 'https://your-ngrok-url.ngrok.io/auth/facebook/callback';
```

---

## 🧪 **測試 Facebook 登入**

### **1. 測試流程**

#### **啟動測試環境**
1. 啟動 Node.js 開發伺服器（localhost:3001）
2. 啟動 ngrok 隧道
3. 更新環境配置檔案
4. 更新 Facebook 開發者控制台設定

#### **測試步驟**
1. 使用 ngrok 網址訪問您的應用程式
2. 點擊 Facebook 登入按鈕
3. 完成 Facebook 登入流程
4. 檢查回調是否正確處理

### **2. 測試檢查清單**

- [ ] Node.js 伺服器正常運行在 port 3001
- [ ] ngrok 隧道正常啟動
- [ ] Facebook 開發者控制台設定已更新
- [ ] 環境配置檔案已更新
- [ ] 可以通過 ngrok 網址訪問應用程式
- [ ] Facebook 登入按鈕正常顯示
- [ ] 點擊後彈出 Facebook 登入視窗
- [ ] 可以完成登入流程
- [ ] 回調 URL 正確處理

---

## 🚨 **常見問題與解決方案**

### **1. ngrok 相關問題**

#### **問題**：ngrok 無法啟動
- **解決**：檢查認證 token 是否正確設定
- **解決**：確認 Node.js 伺服器是否正在運行在 port 3001

#### **問題**：ngrok 網址無法訪問
- **解決**：檢查防火牆設定
- **解決**：確認 ngrok 隧道狀態

### **2. Node.js 伺服器問題**

#### **問題**：伺服器無法啟動
- **解決**：檢查 port 3001 是否被其他服務佔用
- **解決**：確認 server.js 檔案路徑正確

#### **問題**：伺服器啟動但無法訪問
- **解決**：檢查伺服器監聽的 IP 地址
- **解決**：確認防火牆設定

### **3. Facebook 登入問題**

#### **問題**：回調 URL 錯誤
- **解決**：檢查 Facebook 開發者控制台中的 URI 設定
- **解決**：確認 ngrok 網址格式正確

#### **問題**：應用程式網域錯誤
- **解決**：檢查 Facebook 開發者控制台中的網域設定
- **解決**：確認網域格式（不含 https://）

### **4. 環境配置問題**

#### **問題**：環境變數無法載入
- **解決**：檢查 env.local 檔案路徑
- **解決**：確認檔案格式正確

---

## 📋 **ngrok 配置檢查清單**

### **Node.js 伺服器設定**
- [ ] 伺服器正常運行在 port 3001
- [ ] 可以通過 localhost:3001 訪問
- [ ] 伺服器日誌顯示正常

### **ngrok 設定**
- [ ] ngrok 已安裝並加入 PATH
- [ ] 認證 token 已設定
- [ ] 本地 Node.js 伺服器正在運行
- [ ] ngrok 隧道已啟動
- [ ] 獲取到 ngrok 網址

### **Facebook 開發者控制台**
- [ ] OAuth 重新導向 URI 已新增 ngrok 網址
- [ ] 應用程式網域已新增 ngrok 網域
- [ ] 設定已儲存

### **環境配置**
- [ ] env.local 檔案已更新
- [ ] ngrok 網址已填入相關配置
- [ ] 環境變數已重新載入

### **功能測試**
- [ ] 可以通過 ngrok 網址訪問應用程式
- [ ] Facebook 登入功能正常
- [ ] 回調處理正確

---

## 🔄 **切換回本地開發**

### **當不需要 ngrok 時**

#### **更新環境配置**
```bash
# 註解掉 ngrok 相關配置
# FACEBOOK_REDIRECT_URI=https://your-ngrok-url.ngrok.io/auth/facebook/callback

# 使用本地配置
FACEBOOK_REDIRECT_URI=http://localhost:3001/auth/facebook/callback
```

#### **Facebook 開發者控制台**
- 可以保留 ngrok 網址，或暫時移除
- 確保本地網址仍然有效

---

## 📞 **支援與聯絡**

如有問題或需要協助，請聯繫開發團隊或參考：
- [ngrok 官方文檔](https://ngrok.com/docs)
- [Facebook 開發者文檔](https://developers.facebook.com/docs/)
- [ngrok 故障排除指南](https://ngrok.com/docs/using-ngrok/troubleshooting/)
- [Node.js 官方文檔](https://nodejs.org/docs/)

---

## 📋 **配置完成確認**

### **ngrok 配置狀態**
**ngrok 網址**：_________________  
**本地端口**：3001  
**Facebook 回調 URI**：_________________  
**配置完成日期**：_________________  
**配置負責人**：_________________  
**測試狀態**：_________________
