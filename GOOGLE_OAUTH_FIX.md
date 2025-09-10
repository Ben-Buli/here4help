# 🛠️ Google OAuth 重定向問題一鍵修復

## 🚨 問題描述
你的 Google 第三方登入被重定向到 Google 註冊頁面，而不是預期的 OAuth 授權頁面。

## 🎯 一鍵解決方案

### **快速修復**
```bash
# 在專案根目錄執行
./scripts/setup_google_oauth_debug.sh
```

### **清理恢復** 
```bash
# 清理並恢復原始配置
./scripts/cleanup_google_oauth_debug.sh
```

## 📋 修復步驟詳解

### **1. 執行自動設置腳本**
```bash
./scripts/setup_google_oauth_debug.sh
```

這個腳本會：
- ✅ 自動安裝/啟動 ngrok
- ✅ 獲取公開的 ngrok URL  
- ✅ 更新後端 `.env` 配置
- ✅ 更新前端 `web.json` 配置
- ✅ 測試回調 URL 可訪問性
- ✅ 提供 Google Console 設定指引

### **2. 在 Google Cloud Console 設定回調 URL**

腳本執行後會顯示：
```
Google 回調 URL: https://abc123.ngrok.io/here4help/backend/api/auth/google-callback.php
```

前往 [Google Cloud Console](https://console.cloud.google.com/):

1. **API 和服務** → **憑證**
2. 找到 OAuth 2.0 Client ID: `102744926949-bhrnm2970bgt3dfm2nmdbqt03mrvdh3i`
3. 點擊編輯
4. **授權重定向 URI** 添加：
   ```
   https://你的ngrok網址.ngrok.io/here4help/backend/api/auth/google-callback.php
   ```
5. 點擊 **儲存**

### **3. 測試 OAuth 流程**

1. 重新啟動 Flutter Web 應用
2. 嘗試 Google 登入
3. 現在應該重定向到授權頁面，而不是註冊頁面

## 🔍 問題排除

### **如果仍然重定向到註冊頁面**

1. **檢查 ngrok 狀態**
   ```bash
   curl -I https://你的ngrok網址.ngrok.io/here4help/backend/api/auth/google-callback.php
   ```

2. **檢查 Google Console 設定**
   - 確認回調 URL 已正確添加並保存
   - 確認 Client ID 狀態為啟用

3. **查看 ngrok 日誌**
   ```bash
   tail -f ngrok.log
   ```

### **常見錯誤訊息**

| 錯誤 | 原因 | 解決方案 |
|------|------|----------|
| `invalid_client` | Client ID 錯誤或停用 | 檢查 Google Console 中的 Client ID |
| `redirect_uri_mismatch` | 回調 URL 未授權 | 在 Google Console 中添加正確的回調 URL |
| `access_denied` | 用戶拒絕授權 | 正常行為，用戶可重新嘗試 |

## 📊 配置檢查

### **檢查當前配置**
```bash
# 檢查後端配置
grep GOOGLE_REDIRECT_URI backend/.env

# 檢查前端配置  
grep api_origin assets/app_env/web.json

# 檢查 ngrok 狀態
ps aux | grep ngrok
```

## 🧹 完成後清理

測試完成後，執行清理腳本：
```bash
./scripts/cleanup_google_oauth_debug.sh
```

這會：
- ✅ 停止 ngrok 進程
- ✅ 恢復原始配置
- ✅ 清理臨時檔案

## 🔄 切換到生產環境

生產部署時：
1. 在 Google Console 中添加生產環境回調 URL
2. 更新生產環境配置檔案
3. 不需要 ngrok

## 💡 技術說明

### **為什麼需要 ngrok？**
- Google OAuth 需要公開可訪問的回調 URL
- 本地開發環境 `localhost` 不能被 Google 訪問
- ngrok 提供安全的 HTTPS 隧道

### **為什麼重定向到註冊頁面？**
- Client ID 配置錯誤
- 回調 URL 未在 Google Console 中授權
- 本地 URL 無法被 Google 訪問

## 🎉 預期結果

修復後，Google OAuth 流程應該：

1. **點擊 Google 登入**
2. **重定向到授權頁面**（不是註冊頁面）：
   ```
   https://accounts.google.com/o/oauth2/v2/auth?client_id=...
   ```
3. **用戶授權後**重定向回你的應用
4. **完成登入流程**

## 📞 支援

如果遇到問題：
1. 檢查 `ngrok.log` 日誌
2. 查看瀏覽器開發者工具的網絡標籤
3. 確認 Google Console 設定正確

---

### 🚀 立即開始修復：
```bash
./scripts/setup_google_oauth_debug.sh
```
