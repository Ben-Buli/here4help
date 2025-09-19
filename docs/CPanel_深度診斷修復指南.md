# CPanel 深度診斷和修復指南

## 🚨 問題確認
- 命令列測試: ✅ 正常重導到 `/frontend/`
- 瀏覽器測試: ❌ 顯示內部路徑 `/home/hero4helpdemofhs/public_html/frontend/`

## 🔍 可能原因

### 1. 多層 .htaccess 檔案
CPanel 可能有多個 .htaccess 檔案影響路由：
- `/public_html/.htaccess` (主配置)
- `/public_html/frontend/.htaccess` (可能存在的子目錄配置)
- `/public_html/backend/.htaccess` (後端配置)
- `/public_html/admin/.htaccess` (管理後台配置)

### 2. Apache 虛擬主機配置
CPanel 的 Apache 配置可能有額外的重導規則。

### 3. 瀏覽器快取或 DNS 快取
即使無痕模式也可能受到影響。

## 🛠️ 修復步驟

### 步驟 1: 檢查所有 .htaccess 檔案
在 CPanel 文件管理器中檢查：
1. `public_html/.htaccess` (主配置)
2. `public_html/frontend/.htaccess` (如果存在，刪除或檢查)
3. `public_html/backend/.htaccess` (檢查是否影響)
4. `public_html/admin/.htaccess` (檢查是否影響)

### 步驟 2: 檢查 frontend 目錄
確認 `public_html/frontend/` 目錄中沒有額外的 .htaccess 檔案。

### 步驟 3: 強制清除快取
1. 在 CPanel 中清除所有快取
2. 重啟 Apache (如果可能)
3. 等待 5-10 分鐘讓 DNS 快取更新

### 步驟 4: 測試不同瀏覽器
- Chrome 無痕模式
- Firefox 無痕模式
- Safari 無痕模式
- Edge 無痕模式

## 🔧 緊急修復方案

### 方案 A: 修改主 .htaccess
在 `public_html/.htaccess` 中添加更強制的規則：

```apache
# 強制根路徑重導 (添加在最前面)
RewriteCond %{THE_REQUEST} \s/+[?\s]
RewriteRule ^$ /frontend/ [R=301,L]

# 現有的根路徑規則
RewriteCond %{REQUEST_URI} ^/$
RewriteRule ^$ /frontend/ [L,R=301]
```

### 方案 B: 檢查 frontend 目錄
確保 `public_html/frontend/` 目錄中沒有 .htaccess 檔案。

### 方案 C: 使用絕對路徑
修改重導規則使用絕對路徑：

```apache
RewriteCond %{REQUEST_URI} ^/$
RewriteRule ^$ https://hero4help.demofhs.com/frontend/ [L,R=301]
```

## 🧪 測試方法

### 1. 命令列測試
```bash
curl -I https://hero4help.demofhs.com/
# 應該顯示: location: https://hero4help.demofhs.com/frontend/
```

### 2. 瀏覽器測試
- 開啟無痕模式
- 訪問 https://hero4help.demofhs.com
- 檢查地址欄是否顯示正確的 URL

### 3. 網路工具測試
使用瀏覽器開發者工具的 Network 標籤：
- 查看重導鏈
- 確認最終 URL

## 📋 修復檢查清單

- [ ] 檢查所有 .htaccess 檔案
- [ ] 確認 frontend 目錄沒有額外配置
- [ ] 清除所有快取
- [ ] 測試多個瀏覽器
- [ ] 使用網路工具檢查重導鏈
- [ ] 確認最終 URL 正確

## 🚨 如果問題持續

如果問題仍然存在，可能需要：
1. 聯繫 CPanel 支援
2. 檢查 Apache 虛擬主機配置
3. 考慮使用不同的重導方法
4. 檢查是否有 CDN 或代理服務影響
