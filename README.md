# Here4Help - NCCU Social Task Posting APP

一個專為政大學生設計的任務發布和接案平台，提供校園內各種任務的發布、搜尋和接案服務。

## 📱 專案概述

Here4Help 是一個 Flutter 跨平台應用程式，結合 PHP 後端 API，為政大學生提供：
- 任務發布和管理
- 任務搜尋和篩選
- 即時聊天功能
- 學生身份驗證
- 推薦碼系統
- 積分和評價系統

## 🏗️ 專案架構

```
here4help/
├── lib/                    # Flutter 應用程式主要程式碼
├── backend/               # PHP 後端 API
│   ├── api/              # API 端點
│   ├── config/           # 配置檔案
│   └── utils/            # 工具類別
├── admin/                # 後台管理系統 (開發中)
├── android/              # Android 平台配置
├── ios/                  # iOS 平台配置
└── assets/               # 靜態資源
```

## 🚀 快速開始

### 前置需求

- Flutter SDK (>=3.3.0)
- Dart SDK
- PHP 7.4+
- MySQL 5.7+
- MAMP/XAMPP (本地開發)

### Flutter App 設置

1. **安裝依賴**
   ```bash
   flutter pub get
   ```

2. **配置環境**
   - 複製 `backend/config/database.example.php` 為 `backend/config/database.php`
   - 填入您的資料庫連線資訊

3. **運行應用程式**
   ```bash
   flutter run
   ```

### 後端 API 設置

1. **資料庫設置**
   - 建立 MySQL 資料庫
   - 執行 `database_updates/` 目錄中的 SQL 檔案

2. **配置檔案**
   - 修改 `backend/config/database.php` 中的資料庫連線資訊
   - 確保 PHP 環境支援 PDO 和 MySQL

3. **檔案權限**
   - 確保 `backend/uploads/` 目錄可寫入

## 📋 功能特色

### 使用者功能
- ✅ 學生身份驗證
- ✅ 任務發布和管理
- ✅ 任務搜尋和篩選
- ✅ 即時聊天系統
- ✅ 推薦碼系統
- ✅ 積分和評價
- ✅ Google 登入整合

### 管理功能
- 🔄 後台管理系統 (開發中)
- 🔄 任務審核
- 🔄 使用者管理
- 🔄 系統統計

## 🔧 開發指南

### 目錄結構說明

- `lib/` - Flutter 應用程式程式碼
  - `auth/` - 認證相關
  - `task/` - 任務相關
  - `chat/` - 聊天功能
  - `account/` - 帳戶管理
  - `config/` - 應用程式配置

- `backend/` - PHP 後端
  - `api/` - RESTful API 端點
  - `config/` - 資料庫和應用程式配置
  - `utils/` - 共用工具類別

### API 端點

- `POST /api/auth/register.php` - 使用者註冊
- `POST /api/auth/login.php` - 使用者登入
- `GET /api/tasks/list.php` - 取得任務列表
- `POST /api/tasks/create.php` - 建立新任務

## 📝 注意事項

### 安全性
- 請勿將包含敏感資訊的配置檔案推送到 Git
- 使用環境變數管理敏感資訊
- 定期更新依賴套件

### 開發環境
- 使用 MAMP/XAMPP 進行本地開發
- 確保資料庫連線設定正確
- 測試檔案上傳功能

## 🤝 貢獻指南

1. Fork 專案
2. 建立功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交變更 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 開啟 Pull Request

## 📄 授權

此專案採用 MIT 授權條款 - 詳見 [LICENSE](LICENSE) 檔案

## 📞 聯絡資訊

如有問題或建議，請透過以下方式聯絡：
- 專案 Issues
- Email: [您的聯絡信箱]

---

**版本**: 1.2.1+20250717  
**最後更新**: 2025年1月