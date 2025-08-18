# Here4Help 環境配置指南

## 🏗️ 專案架構

```
here4help/
├── backend/                 # PHP 後端
│   ├── .env.example        # 環境變數範例（包含私密配置）
│   ├── .env                # 本地環境變數（gitignore）
│   └── config/             # 配置檔案
├── lib/                    # Flutter 應用程式
├── app_env/                # Flutter 環境配置
│   ├── dev.json            # 開發環境配置（公開配置）
│   ├── staging.json        # 測試環境配置（公開配置）
│   ├── prod.json           # 生產環境配置（公開配置）
│   ├── dart-define-dev.txt # Flutter 開發環境 dart-define
│   ├── dart-define-prod.txt# Flutter 生產環境 dart-define
│   └── *.example.*         # 配置範例檔案
├── scripts/                 # 啟動腳本
│   ├── run_api_local.sh    # 啟動本地 API
│   ├── run_app_dev.sh      # 啟動開發應用程式
│   ├── swap_ngrok.sh       # 切換 ngrok 隧道
│   ├── sync_ngrok_urls.sh  # 同步 ngrok URL
│   └── *.example.sh        # 腳本範例
├── .envrc                   # direnv 自動載入（可選）
└── .gitignore              # Git 忽略檔案
```

## 🔐 安全配置原則

### **前端配置（公開）**
- ✅ **可公開**：API URL、Socket URL、第三方登入的 Client ID
- ❌ **不可公開**：Secret、Private Key、資料庫密碼、JWT Secret

### **後端配置（私密）**
- ✅ **需要完整配置**：第三方登入的 Secret、Private Key
- ✅ **資料庫配置**：主機、端口、用戶名、密碼
- ✅ **JWT 配置**：Secret Key、過期時間

## 🚀 快速開始

### 1. 後端環境配置

```bash
# 複製環境變數範例
cd backend/config
cp env.example .env

# 編輯 .env 檔案，填入實際值
code .env
```

**重要配置項目：**
- 資料庫連接資訊
- JWT Secret
- 第三方登入的完整配置（ID + Secret）

### 2. Flutter 環境配置

```bash
# 複製環境配置範例
cp app_env/dev.example.json app_env/dev.json
cp app_env/dart-define-dev.example.txt app_env/dart-define-dev.txt

# 編輯配置檔案
code app_env/dev.json
code app_env/dart-define-dev.txt
```

**重要配置項目：**
- API 基礎 URL
- Socket 伺服器 URL
- 第三方登入的 Client ID（僅 ID，不要 Secret）

### 3. 啟動服務

```bash
# 啟動本地 API 服務
chmod +x scripts/run_api_local.sh
./scripts/run_api_local.sh

# 啟動 Flutter 開發伺服器
chmod +x scripts/run_app_dev.sh
./scripts/run_app_dev.sh

# 如需要 HTTPS，啟動 ngrok
chmod +x scripts/swap_ngrok.sh
./scripts/swap_ngrok.sh

# 同步 ngrok URL（自動更新所有配置）
chmod +x scripts/sync_ngrok_urls.sh
./scripts/sync_ngrok_urls.sh
```

## 🔧 環境切換

### 開發環境
```bash
# 使用腳本啟動（推薦）
./scripts/run_app_dev.sh

# 手動啟動
flutter run -d chrome --web-port 8080 $(cat app_env/dart-define-dev.txt | tr '\n' ' ')
```

### 生產環境
```bash
flutter run -d chrome --web-port 8080 $(cat app_env/dart-define-prod.txt | tr '\n' ' ')
```

## 📱 Flutter 配置系統

### EnvironmentConfig 類別
- 自動載入對應環境的 JSON 配置檔案
- 區分公開配置（`public`）和應用配置（`app`）
- 提供統一的配置存取介面
- 支援功能開關和環境特定設定

### AppConfig 類別
- 所有 API 端點都從環境配置動態生成
- 不再有硬編碼的 URL
- 支援環境自動切換

## 🔄 ngrok 整合

### 自動 URL 同步
```bash
# 啟動 ngrok 後，自動同步所有 URL
./scripts/sync_ngrok_urls.sh
```

**同步內容：**
- 後端 `.env` 檔案中的回調 URL
- Flutter `dart-define` 檔案中的 API URL
- 自動備份原始配置檔案

## 🔒 安全性

- 所有 `.env` 檔案都已加入 `.gitignore`
- 敏感資訊不會被提交到版本控制
- 使用範例檔案作為配置模板
- 前端只包含公開配置，後端包含私密配置

## 🆘 常見問題

### Q: 環境配置載入失敗？
A: 檢查 `app_env/` 目錄下是否有對應的 JSON 配置檔案

### Q: API 端點無法訪問？
A: 確認 MAMP 正在運行，並檢查 `.env` 檔案中的資料庫配置

### Q: Flutter 應用程式無法啟動？
A: 檢查端口是否被佔用，或使用不同的端口號

### Q: ngrok URL 不同步？
A: 使用 `./scripts/sync_ngrok_urls.sh` 自動同步所有配置

## 📚 進階配置

### direnv 自動載入（可選）
```bash
# 安裝 direnv
brew install direnv

# 在專案目錄中啟用
direnv allow
```

### 自定義環境配置
可以在 `app_env/` 目錄下添加自定義的環境配置檔案，例如：
- `local.json` - 本地開發
- `test.json` - 測試環境
- `demo.json` - 演示環境

### 第三方登入配置檢查清單
- [ ] Google: Client ID（前端）+ Client Secret（後端）
- [ ] Facebook: App ID（前端）+ App Secret + Client Token（後端）
- [ ] Apple: Service ID（前端）+ Team ID + Private Key（後端）
