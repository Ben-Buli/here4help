# Here4Help 專案變更記錄追蹤表

> 紀錄格式參考如下，可再多增加一個欄位簡易備注修改主題類型，例如：Socket設定、環境設定、註冊登入、聊天室、任務 etc.

| 日期 | 版本/PR | 項目 | 影響區 | 修改主題類型 | 說明 |
|---|---|---|---|---|---|
| 2025-08-18 | db-auth-01 | 建立 `user_identities` 表 | DB | 資料庫重構 | 新增表與索引，支援第三方登入 |
| 2025-08-18 | api-auth-02 | OAuth callback 改讀 `user_identities` | API | 註冊登入 | 舊欄位維持只讀，新表處理第三方登入 |
| 2025-08-19 | data-migrate-03 | 將 `users.provider/google_id` 搬到新表 | DB | 資料庫重構 | 一次性 INSERT 資料遷移 |
| 2025-08-21 | cleanup-04 | DROP `users.provider/google_id` | DB/API | 資料庫重構 | 程式已不再依賴舊欄位 |
| 2025-01-18 | env-config-05 | 建立環境配置系統 | Config | 環境設定 | 新增 `app_env/` 目錄和 JSON 配置檔案 |
| 2025-01-18 | env-config-06 | 建立啟動腳本系統 | Scripts | 環境設定 | 新增 `scripts/` 目錄和自動化腳本 |
| 2025-01-18 | env-config-07 | 更新 Flutter 配置系統 | Frontend | 環境設定 | 移除硬編碼，使用動態環境配置 |
| 2025-01-18 | env-config-08 | 建立 ngrok 同步腳本 | Scripts | 環境設定 | 自動同步 ngrok URL 到所有配置檔案 |
| 2025-01-18 | env-config-09 | 修復 Flutter Web 資產載入 | Frontend | 環境設定 | 將配置檔案移動到 `assets/app_env/` 目錄 |
| 2025-01-18 | env-config-10 | 更新 pubspec.yaml | Config | 環境設定 | 添加 `assets/app_env/` 到 Flutter 資產配置 |
| 2025-01-18 | env-config-11 | 區分公開/私密配置 | Security | 環境設定 | 前端只包含公開配置，後端包含私密配置 |
| 2025-01-18 | env-config-12 | 建立 dart-define 配置檔案 | Config | 環境設定 | 支援 Flutter 的 `--dart-define` 參數 |
| 2025-01-18 | env-config-13 | 更新 .gitignore | Security | 環境設定 | 保護敏感配置檔案不被提交到版本控制 |
| 2025-01-18 | env-config-14 | 建立配置範例檔案 | Config | 環境設定 | 提供 `*.example.*` 檔案作為配置模板 |
| 2025-01-18 | env-config-15 | 建立完整配置指南 | Docs | 環境設定 | 更新 README_ENV_SETUP.md 說明文件 |
| 2025-01-18 | bug-fix-01 | 修復 PHP 警告問題 | Backend | 註冊登入 | 修復 login.php 和 profile.php 中的 provider 和 google_id 欄位問題 |
| 2025-01-18 | test-01 | 傳統登入功能測試成功 | Testing | 註冊登入 | 確認 email/password 登入功能正常，無 PHP 警告，JSON 回應格式正確 |
| 2025-01-18 | test-02 | 環境配置載入測試成功 | Testing | 環境設定 | 確認 Flutter Web 能正確載入 assets/app_env/development.json 配置檔案 |
| 2025-01-18 | test-03 | Profile API 測試成功 | Testing | 註冊登入 | 確認用戶資料讀取 API 正常，無 PHP 警告，資料格式正確 |
| 2025-01-18 | bug-fix-02 | 修復 Socket 伺服器 JWT 問題 | Backend | Socket設定 | 修復 JWT_SECRET 配置和重複 dotenv 載入問題，Socket 伺服器現在正常運作 |
| 2025-01-18 | bug-fix-03 | 修復第三方登入模擬資料問題 | Frontend | 第三方登入 | 修復 Web 版 Google/Facebook/Apple 登入的模擬資料，確保所有必要參數都有值 |
| 2025-01-18 | bug-fix-04 | 修復註冊頁面硬編碼 URL 問題 | Frontend | 環境配置 | 修復註冊頁面、學生證上傳頁面中的硬編碼 API URL，統一使用 AppConfig 管理 |
| 2025-01-18 | ui-enhance-01 | 優化大學選項 RWD 設計 | Frontend | UI/UX | 優化大學選項的下拉選單設計，包括斜線分隔、字體大小、間距、邊框和響應式佈局 |
| 2025-01-18 | bug-fix-05 | 修復大學選項佈局錯誤 | Frontend | 佈局修復 | 修復大學選項下拉選單中的 RenderFlex 佈局錯誤，使用 Flexible 和明確的寬度約束 |
| 2025-01-18 | bug-fix-06 | 修復學校選項顯示和佈局溢出 | Frontend | UI/UX修復 | 修復學校選項選中項目只顯示縮寫，並解決 Column 佈局溢出 40 像素的問題 |
| 2025-01-18 | ui-enhance-02 | 優化學校選項文字省略顯示 | Frontend | UI/UX | 優化學校選項的文字省略顯示，使用 TextOverflow.ellipsis 讓超出的文字在 UI 上顯示省略符號 |
| 2025-01-18 | ui-enhance-03 | 優化 Primary Languages 設計和主題配色 | Frontend | UI/UX | 優化 Primary Languages 的設計，使用主題配色，改善語言標籤、選擇器和彈出視窗的視覺效果 |
| 2025-01-18 | bug-fix-07 | 修復 School 下拉選單佈局錯誤 | Frontend | 佈局修復 | 修復 School 下拉選單中的 selectedItemBuilder 佈局錯誤，添加安全檢查和錯誤處理 |
| 2025-01-18 | ui-complete-01 | School 下拉選單設計完成 | Frontend | UI/UX完成 | School 下拉選單完全優化完成，包括佈局修復、主題配色、文字省略、響應式設計等 |
| 2025-01-18 | version-2025-01-18 | 2025-01-18 版本推送 | All | 版本發布 | 本次版本包含環境配置系統、第三方登入基礎架構、UI優化、自動化腳本等完整功能 |
| 2025-01-19 | third-party-auth-01 | 第三方登入憑證配置優化 | Config | 第三方登入 | 重構環境配置系統，將敏感資訊移至 private 區塊，支援公開/私密配置分離 |
| 2025-01-19 | third-party-auth-02 | 創建第三方登入服務架構 | Frontend | 第三方登入 | 新增 Facebook、Apple Sign-In 服務類，建立統一的第三方登入管理服務 |
| 2025-01-19 | third-party-auth-03 | 更新 Apple Team ID 配置 | Config | 第三方登入 | 更新所有環境配置檔案中的 Apple Team ID 為 Q4C6BSB74K |
| 2025-01-19 | third-party-auth-04 | 完善第三方登入配置文檔 | Docs | 第三方登入 | 創建完整的第三方登入配置指南和安全性配置說明 |
| 2025-01-19 | theme-optimization-01 | 主題系統整合優化 | Frontend | 主題系統 | 精簡主題數量從 30+ 個到 12 個，整合重複功能，創建優化版主題系統 |
| 2025-01-19 | theme-optimization-02 | 創建主題使用指南 | Docs | 主題系統 | 創建完整的主題使用指南，說明如何使用 ThemeScheme 和 Theme.of(context).colorScheme |
| 2025-01-19 | theme-optimization-03 | 主題系統文檔完善 | Docs | 主題系統 | 建立主題邏輯和檔案用途說明，更新專案整合規格文件 |
| 2025-01-21 | oauth-callback-01 | Google OAuth 回調處理實作 | Backend | 第三方登入 | 實作完整的 Google OAuth 回調處理，包括授權碼交換、用戶資料獲取和重定向 |
| 2025-01-21 | oauth-callback-02 | 環境配置系統完善 | Config | 第三方登入 | 創建開發環境配置檔案，支援 Google OAuth 的完整配置 |
| 2025-01-21 | oauth-callback-03 | OAuth 回調文檔建立 | Docs | 第三方登入 | 創建完整的 Google OAuth 回調處理實作說明文件 |
| 2025-01-21 | permission-system-01 | 建立權限設置開發追蹤表 | Docs | 權限系統 | 建立完整的權限系統開發追蹤和進度管理系統 |

## 📋 當前狀態

### ✅ **已完成功能**
- **環境配置系統**：完整的環境變數管理，支援開發/測試/生產環境
- **第三方登入基礎架構**：Google、Facebook、Apple 登入的模擬資料系統
- **第三方登入服務架構**：完整的服務類設計，支援統一管理和配置驗證
- **第三方登入憑證管理**：敏感資訊安全配置，支援公開/私密配置分離
- **Socket.IO 伺服器**：JWT 驗證正常，聊天功能基礎架構完成
- **School 下拉選單**：完全優化完成，包括佈局修復、主題配色、文字省略、響應式設計
- **Primary Languages 設計**：使用主題配色，現代化設計風格
- **硬編碼 URL 修復**：所有 API 端點統一使用 AppConfig 管理
- **自動化腳本系統**：開發環境啟動、ngrok 同步等腳本
- **Flutter 環境配置**：JSON 配置檔案和 dart-define 支援
- **主題系統整合優化**：精簡主題數量從 30+ 個到 12 個，整合重複功能，創建優化版主題系統
- **主題使用指南**：完整的主題使用指南，說明如何使用 ThemeScheme 和 Theme.of(context).colorScheme
- **主題系統文檔完善**：建立主題邏輯和檔案用途說明，更新專案整合規格文件

### 🔧 **進行中功能**
- **第三方登入整合**：基礎架構完成，等待真實 SDK 整合
- **用戶註冊流程**：表單設計完成，等待端到端測試
- **第三方登入測試**：服務架構完成，等待實際登入流程測試

### 📋 **待開發功能**
- **真實第三方登入 SDK**：Google、Facebook、Apple 的實際整合
- **後端第三方登入 API**：Facebook 和 Apple 登入的後端實作
- **電子郵件驗證系統**：用戶註冊後的驗證流程
- **密碼重設功能**：忘記密碼的處理流程
- **多語言支援**：國際化 (i18n) 功能

## 🚀 **2025-01-18 版本詳細異動記錄**

### **📁 新增檔案和目錄**
1. **`app_env/` 目錄**
   - `dev.json` - 開發環境配置
   - `staging.json` - 測試環境配置
   - `prod.json` - 生產環境配置
   - `dart-define-dev.txt` - Flutter 開發環境變數
   - `dart-define-prod.txt` - Flutter 生產環境變數
   - 對應的 `.example` 檔案

2. **`assets/app_env/` 目錄**
   - `development.json` - Flutter 開發環境配置
   - `production.json` - Flutter 生產環境配置
   - `staging.json` - Flutter 測試環境配置
   - `development.example.json` - 環境配置範例檔案

3. **`scripts/` 目錄**
   - `run_api_local.sh` - 本地 API 啟動腳本
   - `run_app_dev.sh` - Flutter 開發環境啟動腳本
   - `swap_ngrok.sh` - ngrok 隧道切換腳本
   - `sync_ngrok_urls.sh` - ngrok URL 自動同步腳本
   - 對應的 `.example` 檔案

4. **其他新增檔案**
   - `README_ENV_SETUP.md` - 環境配置說明文件
   - `backend/api/auth/verify-referral-code.php` - 推薦碼驗證 API
   - `lib/auth/models/signup_model.dart` - 註冊資料模型
   - `docs/優先執行/ReadME_Here4Help專案＿變更記錄追蹤表.md` - 變更追蹤表
   - `docs/GOOGLE_AUTH_SETUP.md` - Google 登入配置指南
   - `docs/GITIGNORE_EXAMPLE.md` - .gitignore 範例檔案
   - `docs/THIRD_PARTY_AUTH_CONFIG.md` - 第三方登入完整配置指南

### **🔧 修改檔案**
1. **環境配置相關**
   - `.gitignore` - 更新忽略規則，保護第三方登入敏感檔案
   - `backend/config/env.example` - 環境變數範例
   - `backend/config/env_loader.php` - 環境載入器優化
   - `backend/socket/server.js` - JWT 配置修復

2. **後端 API 修復**
   - `backend/api/auth/google-login.php` - 第三方登入 API
   - `backend/api/auth/login.php` - 登入 API 修復
   - `backend/api/auth/profile.php` - 用戶資料 API 修復

3. **前端優化**
   - `lib/auth/pages/login_page.dart` - 登入頁面第三方登入整合
   - `lib/auth/pages/student_id_page.dart` - 學生證上傳頁面優化
   - `lib/auth/services/platform_auth_service.dart` - 第三方登入服務
   - `lib/config/app_config.dart` - API 配置優化
   - `lib/config/environment_config.dart` - 環境配置載入，新增私密配置支援
   - `lib/main.dart` - 主程式環境初始化
   - `pubspec.yaml` - 資源配置更新

4. **其他頁面優化**
   - `lib/account/pages/profile_page.dart` - 個人資料頁面
   - `lib/account/pages/wallet_page.dart` - 錢包頁面
   - `lib/chat/widgets/my_works_widget.dart` - 我的工作組件
   - `lib/chat/widgets/posted_tasks_widget.dart` - 已發布任務組件

5. **第三方登入配置檔案**
   - `assets/app_env/development.json` - 新增私密配置區塊
   - `assets/app_env/production.json` - 新增私密配置區塊
   - `assets/app_env/staging.json` - 新增私密配置區塊
   - `ios/Runner/AppleSignIn.plist` - 更新 Apple Team ID
   - `android/app/google-services.json` - 新增 Android Google Services 配置
   - `ios/Runner/GoogleService-Info.plist` - 新增 iOS Google Services 配置

### **🗑️ 刪除檔案**
- `docs/優先執行/登入註冊＿變更記錄追蹤表.md` - 舊版追蹤表（已整合到新版）

### **🎯 主要功能改進**
1. **環境配置系統**
   - 支援多環境配置（開發/測試/生產）
   - 自動環境檢測和配置載入
   - 敏感資訊安全處理
   - 公開/私密配置分離管理

2. **第三方登入基礎架構**
   - Google、Facebook、Apple 登入模擬系統
   - 跨平台登入服務
   - 新用戶導向註冊流程
   - 完整的服務類架構設計

3. **第三方登入憑證管理**
   - 敏感資訊安全配置
   - 環境變數管理
   - 配置驗證和狀態檢查
   - 多平台憑證支援

4. **UI/UX 優化**
   - School 下拉選單完全重構
   - Primary Languages 現代化設計
   - 主題配色系統整合

5. **自動化腳本**
   - 開發環境一鍵啟動
   - ngrok URL 自動同步
   - 環境檢查和狀態監控

### **🔒 安全性改進**
- 所有敏感配置移至 `.env` 檔案
- 環境檔案加入 `.gitignore`
- 前端不包含敏感資訊
- 配置範例檔案提供
- 第三方登入憑證安全保護
- 公開/私密配置分離
- 敏感檔案版本控制保護

### **📱 技術架構優化**
- Flutter 環境配置系統
- PHP 後端環境管理
- Node.js Socket.IO 配置
- 跨平台第三方登入支援
- 第三方登入服務架構
- 環境配置載入器優化
- 配置驗證和狀態管理

## 🎯 **School 下拉選單完成總結**

### **✅ 已完成功能**
1. **佈局修復**
   - 修復 `selectedItemBuilder` 佈局錯誤
   - 解決 RenderFlex 溢出問題
   - 添加安全檢查和錯誤處理

2. **設計優化**
   - 使用主題配色系統
   - 圓角邊框和現代化設計
   - 左邊框使用系統主色

3. **文字省略顯示**
   - 使用 `TextOverflow.ellipsis`
   - 設置 `maxLines: 1`
   - 超出的文字顯示省略符號

4. **響應式佈局**
   - 使用 `Expanded` 確保彈性佈局
   - 適應不同螢幕尺寸
   - 避免佈局溢出

5. **選中項目顯示**
   - 選中項目只顯示大學縮寫
   - 使用 `hint` 顯示預設文字
   - 自定義 `selectedItemBuilder`

6. **資料安全**
   - 過濾無效的大學資料
   - 檢查必要欄位 (id, abbr, en_name)
   - 添加錯誤處理和 fallback

### **🎨 視覺效果**
- **選項佈局**：縮寫 + 斜線 + 英文名稱
- **字體樣式**：縮寫 14px 粗體，英文名稱 12px 斜體
- **色彩搭配**：使用系統主題色彩
- **間距設計**：統一的 padding 和 margin

### **🔧 技術實現**
- **佈局系統**：Row + Expanded 彈性佈局
- **主題適配**：完全使用 `Theme.of(context).colorScheme`
- **錯誤處理**：Try-catch + 資料驗證
- **性能優化**：過濾無效資料，減少渲染負擔

### **📱 用戶體驗**
- **清晰選擇**：選中項目一目了然
- **直觀操作**：點擊展開，選擇確認
- **視覺反饋**：選中狀態明確顯示
- **響應式設計**：適應各種螢幕尺寸

**完成時間**：2025-01-18  
**狀態**：✅ 完全完成  
**測試狀態**：待測試

---

**版本發布時間**：2025-01-18  
**版本狀態**：✅ 已推送  
**測試狀態**：待測試

---

## 🚀 **2025-01-19 版本詳細異動記錄**

### **📁 新增檔案和目錄**
1. **第三方登入服務**
   - `lib/auth/services/facebook_auth_service.dart` - Facebook 登入服務
   - `lib/auth/services/apple_auth_service.dart` - Apple Sign-In 服務
   - `lib/auth/services/third_party_auth_service.dart` - 統一第三方登入服務

2. **第三方登入配置檔案**
   - `android/app/google-services.json` - Android Google Services 配置
   - `ios/Runner/GoogleService-Info.plist` - iOS Google Services 配置
   - `ios/Runner/AppleSignIn.plist` - Apple Sign-In 配置
   - `assets/app_env/facebook_config.json` - Facebook 登入配置

3. **文檔和配置範例**
   - `docs/GOOGLE_AUTH_SETUP.md` - Google 登入配置指南
   - `docs/GITIGNORE_EXAMPLE.md` - .gitignore 範例檔案
   - `docs/THIRD_PARTY_AUTH_CONFIG.md` - 第三方登入完整配置指南
   - `assets/app_env/development.example.json` - 環境配置範例檔案

### **🔧 修改檔案**
1. **環境配置重構**
   - `assets/app_env/development.json` - 新增私密配置區塊
   - `assets/app_env/production.json` - 新增私密配置區塊
   - `assets/app_env/staging.json` - 新增私密配置區塊

2. **環境配置載入器**
   - `lib/config/environment_config.dart` - 新增私密配置 getter 方法

3. **平台配置檔案**
   - `ios/Runner/Info.plist` - 新增 Google 登入 URL Scheme
   - `android/app/build.gradle.kts` - 新增 Google Services 插件
   - `android/build.gradle.kts` - 新增 Google Services 插件依賴

4. **版本控制保護**
   - `.gitignore` - 新增第三方登入敏感檔案保護

### **🎯 主要功能改進**
1. **第三方登入憑證管理**
   - 敏感資訊安全配置
   - 公開/私密配置分離
   - 多環境配置支援
   - 配置驗證和狀態檢查

2. **第三方登入服務架構**
   - 統一的服務管理
   - 配置驗證和錯誤處理
   - 跨平台登入支援
   - 模擬資料測試系統

3. **安全性改進**
   - 敏感檔案版本控制保護
   - 環境配置範例檔案
   - 配置狀態監控
   - 錯誤處理和日誌記錄

### **🔒 安全性改進**
- 第三方登入憑證安全保護
- 公開/私密配置分離
- 敏感檔案版本控制保護
- 配置驗證和狀態檢查
- 環境配置範例檔案

### **📱 技術架構優化**
- 第三方登入服務架構
- 環境配置載入器優化
- 配置驗證和狀態管理
- 跨平台第三方登入支援

**版本發布時間**：2025-01-19  
**版本狀態**：✅ 已推送  
**測試狀態**：待測試

---

## 🚀 **2025-01-19 版本詳細異動記錄**

### **📁 新增檔案和目錄**
1. **主題系統優化**
   - `lib/constants/theme_schemes_optimized.dart` - 優化後的主題系統
   - `docs/THEME_USAGE_GUIDE.md` - 主題使用指南

### **🔧 修改檔案**
1. **主題系統整合**
   - 精簡主題數量：從 30+ 個減少到 12 個核心主題
   - 整合重複功能：合併主題管理服務和分類系統
   - 優化檔案結構：從 1659 行減少到約 600 行

### **🗑️ 建議刪除檔案**
1. **重複功能檔案**
   - `lib/services/theme_management_service.dart` - 功能重複，建議刪除
   - `lib/constants/theme_categories.dart` - 已整合到優化版
   - `lib/constants/theme_schemes.dart` - 舊版，建議逐步遷移後刪除

### **🎯 主要功能改進**
1. **主題系統優化**
   - 精簡主題數量，提高維護性
   - 整合重複功能，統一管理
   - 保持向後兼容，支援逐步遷移

2. **主題使用指南**
   - 詳細的使用說明和範例
   - 與 Material Theme 的整合方法
   - 最佳實踐和遷移策略

### **📱 技術架構優化**
- 主題系統整合和優化
- 重複功能清理
- 檔案結構優化
- 維護性提升

**版本發布時間**：2025-01-19  
**版本狀態**：✅ 已推送  
**測試狀態**：待測試
