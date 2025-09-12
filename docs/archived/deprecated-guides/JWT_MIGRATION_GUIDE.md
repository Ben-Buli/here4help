# 🔐 JWT 遷移指南

## 📋 概述

本文檔記錄了 Here4Help 專案從舊版 base64 編碼 token 系統遷移到標準 JWT (JSON Web Token) 系統的完整過程。

## 🎯 遷移目標

- **安全性提升**：從無簽名驗證的 base64 token 升級到有簽名驗證的 JWT
- **標準化**：符合 RFC 7519 JWT 標準
- **演算法鎖定**：防止 alg:none 攻擊
- **向後兼容**：支援舊版 token 格式，確保平滑遷移
- **統一驗證**：建立統一的 token 驗證介面

## 🏗️ 系統架構

### 核心組件

1. **JWTManager** (`backend/utils/JWTManager.php`)
   - JWT token 生成、驗證、刷新
   - 演算法鎖定 (HS256)
   - 時間驗證 (iat, exp, nbf)

2. **TokenValidator** (`backend/utils/TokenValidator.php`)
   - 統一 token 驗證介面
   - 支援 JWT 和舊版 base64 格式
   - 向後兼容性

3. **環境配置**
   - JWT_SECRET 密鑰管理
   - 過期時間設定
   - 演算法配置

## 📁 已更新的檔案

### 🔐 認證系統
- `backend/api/auth/login.php` - 登入 API，生成 JWT token
- `backend/api/auth/google-login.php` - Google 登入 API
- `backend/api/auth/profile.php` - 用戶資料 API

### 💬 聊天系統
- `backend/api/chat/send_message.php` - 發送訊息 API（範例）

### 🛠️ 工具類
- `backend/utils/JWTManager.php` - JWT 管理工具
- `backend/utils/TokenValidator.php` - Token 驗證工具

### 📝 配置檔案
- `backend/config/env.example` - 環境配置範例
- `backend/.htaccess` - Apache 配置

### 🧪 測試工具
- `backend/test_jwt.php` - JWT 功能測試
- `backend/scripts/migrate_to_jwt.php` - 批量遷移腳本

## 🚀 遷移步驟

### 階段 1：環境準備

1. **設定 JWT 密鑰**
   ```bash
   # 生成強密鑰（至少 32 字元）
   openssl rand -base64 32
   ```

2. **更新 .env 檔案**
   ```env
   JWT_SECRET=your_super_secret_jwt_key_here_minimum_32_characters
   JWT_EXPIRY=604800
   JWT_ALGORITHM=HS256
   JWT_REFRESH_THRESHOLD=3600
   ```

3. **確認 .htaccess 配置**
   ```apache
   # 關鍵：使用 SetEnvIf 轉發 Authorization 頭到 PHP
   SetEnvIf Authorization "(.*)" HTTP_AUTHORIZATION=$1
   ```

### 階段 2：核心系統更新

1. **更新認證 API**
   - 登入 API 使用 JWT 生成
   - 用戶資料 API 使用 JWT 驗證

2. **建立工具類**
   - JWTManager 處理 JWT 操作
   - TokenValidator 提供統一驗證介面

### 階段 3：批量遷移

1. **執行遷移腳本**
   ```bash
   cd backend/scripts
   php migrate_to_jwt.php
   ```

2. **手動檢查關鍵 API**
   - 聊天系統 API
   - 任務系統 API
   - 其他業務邏輯 API

### 階段 4：測試驗證

1. **運行 JWT 測試**
   ```bash
   cd backend
   php test_jwt.php
   ```

2. **API 功能測試**
   - 登入功能
   - Token 驗證
   - 授權檢查

## 🔧 技術細節

### JWT 結構

```
Header.Payload.Signature
```

- **Header**: 演算法和類型資訊
- **Payload**: 用戶資料和時間戳
- **Signature**: HMAC-SHA256 簽名

### Token 載荷

```json
{
  "user_id": 123,
  "email": "user@example.com",
  "name": "用戶名稱",
  "iat": 1641234567,
  "exp": 1641839367,
  "nbf": 1641234567
}
```

### 安全特性

- **演算法鎖定**：只允許 HS256
- **時間驗證**：iat, exp, nbf 三重檢查
- **簽名驗證**：防止 token 篡改
- **密鑰管理**：環境變數配置

## 📊 向後兼容性

### 支援的 Token 格式

1. **新版 JWT**（優先）
   - 標準 JWT 格式
   - 完整簽名驗證
   - 時間驗證

2. **舊版 Base64**（兼容）
   - 原有 base64 編碼格式
   - 基本時間檢查
   - 逐步淘汰

### 遷移策略

- **雙軌制**：同時支援兩種格式
- **優先級**：JWT 優先，base64 備用
- **平滑過渡**：用戶無感知遷移

## 🧪 測試指南

### 功能測試

1. **JWT 生成測試**
   ```php
   $token = JWTManager::generateToken($payload);
   ```

2. **JWT 驗證測試**
   ```php
   $payload = JWTManager::validateToken($token);
   ```

3. **Token 刷新測試**
   ```php
   $newToken = JWTManager::refreshToken($token);
   ```

### 錯誤處理測試

1. **無效 Token**
2. **過期 Token**
3. **篡改 Token**
4. **空 Token**

### 性能測試

1. **Token 生成速度**
2. **驗證響應時間**
3. **並發處理能力**

## 🚨 注意事項

### 安全考量

1. **密鑰管理**
   - 使用強密鑰（至少 32 字元）
   - 定期更換密鑰
   - 環境變數配置

2. **Token 過期**
   - 設定合理的過期時間
   - 實現自動刷新機制
   - 監控過期情況

3. **演算法安全**
   - 鎖定為 HS256
   - 防止 alg:none 攻擊
   - 定期安全審查

### 部署考量

1. **環境配置**
   - 開發/測試/正式環境分離
   - 密鑰管理策略
   - 監控和日誌

2. **回滾計劃**
   - 備份原始檔案
   - 快速回滾機制
   - 數據一致性檢查

## 📈 監控和維護

### 日誌監控

1. **JWT 操作日誌**
   - Token 生成記錄
   - 驗證成功/失敗
   - 過期和刷新

2. **錯誤追蹤**
   - 驗證失敗原因
   - 格式錯誤統計
   - 性能問題識別

### 性能指標

1. **響應時間**
   - Token 生成時間
   - 驗證響應時間
   - 整體 API 性能

2. **使用統計**
   - Token 使用量
   - 過期和刷新頻率
   - 錯誤率統計

## 🔮 未來規劃

### 短期目標

1. **完成所有 API 遷移**
2. **建立完整測試套件**
3. **性能優化**

### 長期目標

1. **JWT 標準升級**
2. **多因素認證**
3. **OAuth 2.0 整合**

## 📞 支援和聯繫

### 技術支援

- **開發團隊**：Here4Help Team
- **文檔維護**：定期更新和檢查
- **問題回報**：GitHub Issues

### 更新記錄

- **v2.0.0** (2025-01-11): 初始 JWT 實現
- **v2.1.0** (計劃): 性能優化
- **v2.2.0** (計劃): 功能擴展

## 🗑️ 2025-08-17 清理記錄

### 清理的備份文件數量
- **總計清理**: 105 個備份文件
- **清理時間**: 2025年8月17日
- **清理原因**: 準備版本推送，清理臨時備份文件

### 清理的備份文件類型
1. **JWT 遷移備份** (`*.jwt-migration-backup.*`)
   - 數量: 約 50+ 個文件
   - 位置: `backend/api/auth/`, `backend/api/chat/`, `backend/api/tasks/`
   - 清理理由: JWT 遷移已完成，備份文件不再需要

2. **清理過程備份** (`*.cleanup-backup.*`)
   - 數量: 約 30+ 個文件
   - 位置: 各 API 目錄
   - 清理理由: 語法錯誤修復完成，備份文件不再需要

3. **修復過程備份** (`*.fix-backup.*`)
   - 數量: 約 15+ 個文件
   - 位置: 各 API 目錄
   - 清理理由: 各種修復腳本執行完成，備份文件不再需要

4. **高級修復備份** (`*.advanced-fix-backup.*`)
   - 數量: 約 6 個文件
   - 位置: 各 API 目錄
   - 清理理由: 高級修復腳本執行完成，備份文件不再需要

5. **智能修復備份** (`*.smart-fix-backup.*`)
   - 數量: 約 6 個文件
   - 位置: 各 API 目錄
   - 清理理由: 智能修復腳本執行完成，備份文件不再需要

### 清理命令執行記錄
```bash
# 清理所有類型的備份文件
find backend -name "*.jwt-migration-backup.*" -delete
find backend -name "*.backup.*" -delete
find backend -name "*.cleanup-backup.*" -delete
find backend -name "*.fix-backup.*" -delete
find backend -name "*.advanced-fix-backup.*" -delete
find backend -name "*.smart-fix-backup.*" -delete
```

### 清理後狀態
- ✅ 所有備份文件已清理
- ✅ 工作目錄乾淨，準備版本推送
- ✅ 保留重要文件：JWTManager.php, TokenValidator.php, 遷移腳本等
- ✅ 保留文檔：JWT_MIGRATION_GUIDE.md

---

**最後更新**: 2025-08-17  
**版本**: 2.0.1  
**作者**: Here4Help Team
