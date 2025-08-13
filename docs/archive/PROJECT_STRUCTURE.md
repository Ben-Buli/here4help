# 項目結構說明

## 📁 目錄組織

### 主要代碼目錄
```
here4help/
├── lib/                    # Flutter 主要代碼
├── android/               # Android 平台代碼
├── ios/                   # iOS 平台代碼
├── web/                   # Web 平台代碼
├── backend/               # 正式後端 API
└── assets/                # 靜態資源
```

### 文檔管理目錄 (`docs/`)
```
docs/
├── theme-updates/         # 主題更新相關文檔
│   ├── META_BUSINESS_PURPLE_THEME_UPDATE.md
│   ├── META_BUSINESS_THEME_UPDATE.md
│   ├── THEME_PAGE_ENGLISH_TRANSLATION.md
│   ├── THEME_PAGE_SCAFFOLD_FIX.md
│   ├── THEME_PROVIDER_FIX_SUMMARY.md
│   ├── THEME_SERVICE_FIX_SUMMARY.md
│   ├── THEME_STYLE_DEFAULT_TO_STANDARD_FIX.md
│   ├── THEME_CONFIG_SYSTEM_OPTIMIZATION.md
│   └── THEME_UPDATE_PUSH_COMMANDS.md
├── development-logs/      # 開發日誌
│   ├── FLUTTER_APP_DEVELOPMENT_LOG.md
│   ├── MIGRATION_COMPLETE.md
│   ├── MIGRATION_GUIDE.md
│   ├── NAVIGATION_DEBUG_GUIDE.md
│   ├── PATH_MAPPING_GUIDE.md
│   ├── ROUTING_NAVIGATION_FIX.md
│   └── UI_STYLE_GUIDE.md
└── bug-fixes/            # 錯誤修復文檔
    ├── BUG_FIXES_SUMMARY.md
    ├── CHAT_LIST_LAYOUT_FIX.md
    ├── CIRCLE_AVATAR_FIX.md
    ├── DROPDOWN_ERROR_FIX.md
    ├── HEXAGON_ACHIEVEMENTS_UPDATE.md
    ├── TASK_PAGE_EDIT_ICON_ADDITION.md
    ├── TASK_STATUS_FIX_SUMMARY.md
    └── COLORS_BLUE_TO_THEME_SUMMARY.md
```

### 開發工具目錄 (`dev-tools/`)
```
dev-tools/
├── scripts/              # 開發腳本
│   └── push_flutter_app.sh
├── php-test/             # PHP 測試文件
│   ├── backend_example/
│   ├── database_languages_update.sql
│   ├── database_updates/
│   ├── languages_clean_insert.sql
│   ├── languages_insert.sql
│   └── phpmyadmin_languages.sql
└── test-files/           # 測試文件
    ├── test_images/
    ├── flutter_01.png
    └── test_meta_theme_page.dart
```

## 📋 文檔分類說明

### 主題更新文檔 (`docs/theme-updates/`)
- **用途**: 記錄所有主題相關的更新和修改
- **內容**: 主題配色調整、UI 風格變更、主題系統優化
- **特點**: 包含詳細的技術實現和視覺效果說明

### 開發日誌 (`docs/development-logs/`)
- **用途**: 記錄開發過程中的重要決策和技術實現
- **內容**: 架構設計、遷移指南、調試過程、UI 設計指南
- **特點**: 提供開發參考和最佳實踐

### 錯誤修復文檔 (`docs/bug-fixes/`)
- **用途**: 記錄問題修復過程和解決方案
- **內容**: Bug 描述、修復方法、測試結果
- **特點**: 便於問題追蹤和知識積累

## 🛠️ 開發工具說明

### 腳本文件 (`dev-tools/scripts/`)
- **用途**: 自動化開發和部署流程
- **內容**: 推送腳本、構建腳本、測試腳本
- **使用**: 提高開發效率，減少重複操作

### PHP 測試文件 (`dev-tools/php-test/`)
- **用途**: 後端 API 測試和數據庫操作
- **內容**: 測試 API、數據庫腳本、示例代碼
- **特點**: 非正式項目內容，僅用於開發測試

### 測試文件 (`dev-tools/test-files/`)
- **用途**: UI 測試和開發調試
- **內容**: 測試圖片、測試頁面、調試工具
- **特點**: 不包含在正式發布中

## 📝 推送指令管理

### 推送指令文檔位置
- **文件**: `docs/theme-updates/THEME_UPDATE_PUSH_COMMANDS.md`
- **內容**: 詳細的 Git 推送指令和提交信息
- **分類**: 
  1. 主題設置相關推送
  2. 因主題設置而調整的內容推送

### 推送指令特點
- **分類清晰**: 按功能模塊分類推送
- **描述詳細**: 包含具體的修改內容和影響
- **批量推送**: 提供單個和批量推送選項
- **檢查清單**: 推送前後驗證項目

## 🔄 維護指南

### 新增文檔
1. 根據文檔類型選擇對應目錄
2. 使用清晰的命名規範
3. 在文檔中包含必要的技術細節
4. 更新相關的索引或說明文件

### 更新推送指令
1. 記錄具體的修改內容
2. 分類到對應的推送類型
3. 提供詳細的提交信息
4. 包含必要的驗證步驟

### 清理舊文件
1. 定期檢查和清理過時文檔
2. 移除不再使用的測試文件
3. 更新相關的引用和鏈接
4. 保持目錄結構的整潔

## 📊 項目結構優勢

### 組織性
- 文檔按功能分類，便於查找
- 開發工具集中管理，避免混亂
- 清晰的目錄層次結構

### 可維護性
- 分離正式代碼和測試內容
- 統一的文檔管理方式
- 標準化的推送流程

### 可擴展性
- 易於添加新的文檔類型
- 靈活的目錄結構設計
- 支持團隊協作開發 