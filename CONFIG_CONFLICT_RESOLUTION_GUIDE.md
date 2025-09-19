# Here4Help 配置衝突解決指南

## 🔍 發現的配置衝突

### 1. CORS 設定衝突
**問題**：
- `.htaccess`: `Access-Control-Allow-Origin "*"` (允許所有來源)
- `production.env`: `CORS_ALLOWED_ORIGINS="https://hero4help.demofhs.com"` (限制特定域名)

**解決方案**：
- 使用修正後的 `.htaccess_production_fixed`
- 限制 CORS 到特定域名，提高安全性

### 2. 檔案上傳大小限制衝突
**問題**：
- `.htaccess`: `php_value upload_max_filesize 10M`
- `production.env`: `ADMIN_UPLOAD_MAX_SIZE=5242880` (5MB)

**解決方案**：
- 統一使用 10MB 作為一般上傳限制
- Admin 上傳限制保持 5MB (較嚴格)

### 3. 安全標頭設定不一致
**問題**：
- 安全標頭分散在 `.htaccess` 和 `production.env` 中
- 可能造成設定不一致

**解決方案**：
- 統一在 `.htaccess` 中設定安全標頭
- `production.env` 專注於應用程式配置

### 4. 檔案保護設定衝突
**問題**：
- `.htaccess`: 禁止訪問 `.env` 檔案
- Backend: 需要載入 `.env` 檔案

**解決方案**：
- 修正 `.htaccess` 檔案保護設定
- 允許 Backend 載入器訪問 `.env` 檔案

## 🛠️ 修正步驟

### 步驟 1：備份現有配置
```bash
cp .htaccess .htaccess.backup
cp env/production.env env/production.env.backup
```

### 步驟 2：應用修正後的配置
```bash
# 使用修正後的 .htaccess
cp .htaccess_production_fixed .htaccess

# 使用修正後的 production.env
cp env/production.env.fixed env/production.env
```

### 步驟 3：驗證配置
```bash
# 測試環境變數載入
php test_env_integration.php

# 測試 API 端點
curl -X GET "https://hero4help.demofhs.com/backend/api/ping.php"
```

## 📋 配置一致性檢查清單

### ✅ CORS 設定
- [ ] `.htaccess` 限制特定域名
- [ ] `production.env` CORS_ALLOWED_ORIGINS 設定正確
- [ ] 測試跨域請求正常

### ✅ 檔案上傳設定
- [ ] `.htaccess` upload_max_filesize 10M
- [ ] `production.env` UPLOAD_MAX_SIZE=10485760
- [ ] Admin 上傳限制 5MB

### ✅ 安全標頭設定
- [ ] `.htaccess` 設定所有安全標頭
- [ ] `production.env` Session 設定一致
- [ ] 測試安全標頭正常

### ✅ 檔案保護設定
- [ ] `.htaccess` 允許 Backend 載入 `.env`
- [ ] 禁止直接訪問敏感檔案
- [ ] 測試檔案保護正常

## 🚨 重要注意事項

### 1. 部署順序
1. 先部署修正後的 `.htaccess`
2. 再部署修正後的 `production.env`
3. 最後測試所有功能

### 2. 測試重點
- CORS 跨域請求
- 檔案上傳功能
- 安全標頭檢查
- API 端點訪問

### 3. 回滾計劃
如果修正後出現問題：
```bash
# 回滾到備份配置
cp .htaccess.backup .htaccess
cp env/production.env.backup env/production.env
```

## 🔧 自動化檢查腳本

建立 `check_config_consistency.php` 來自動檢查配置一致性：

```php
<?php
// 檢查配置一致性
echo "=== 配置一致性檢查 ===\n";

// 檢查 CORS 設定
// 檢查檔案上傳設定
// 檢查安全標頭設定
// 檢查檔案保護設定

echo "檢查完成！\n";
?>
```

## 📊 配置衝突解決總結

| 衝突項目 | 原始設定 | 修正後設定 | 狀態 |
|---------|---------|-----------|------|
| CORS | 允許所有來源 | 限制特定域名 | ✅ 已修正 |
| 檔案上傳 | 10MB vs 5MB | 統一 10MB | ✅ 已修正 |
| 安全標頭 | 分散設定 | 統一在 .htaccess | ✅ 已修正 |
| 檔案保護 | 禁止 .env 訪問 | 允許 Backend 載入 | ✅ 已修正 |

## 🎯 下一步行動

1. **立即應用修正**：使用修正後的配置文件
2. **測試功能**：驗證所有功能正常
3. **監控日誌**：檢查是否有錯誤
4. **更新文檔**：記錄配置變更

---

**注意**：修正後的配置已考慮到生產環境的安全性和效能需求，建議在測試環境先驗證後再部署到生產環境。
