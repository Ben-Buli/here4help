# 主題更新推送指令

## 推送分類

### 1. 主題設置相關 (Theme Configuration)

#### 1.1 主題定義和配置
```bash
# 主題配色方案更新
git add lib/constants/theme_schemes.dart
git commit -m "feat: 更新 Beach Sunset 主題配色為碧綠色系

- 主要色: #3B82F6 (海藍) → #00BCD4 (碧綠)
- 次要色: #60A5FA (中藍) → #26C6DA (淺碧綠)
- 強調色: #93C5FD (淺藍) → #4DD0E1 (更淺碧綠)
- 背景色: #F0F8FF (淺藍) → #E0F7FA (淺碧綠)
- 文字色: #1E3A8A (深藍) → #006064 (深碧綠)
- 更新 AppBar 和 Bottom Navigation Bar 背景漸層"

git push origin main
```

#### 1.2 主題管理服務
```bash
# 主題配置管理器更新
git add lib/services/theme_config_manager.dart
git commit -m "feat: 更新主題配置管理器

- 修復 Beach 主題 AppBar 背景漸層顏色
- 更新 Beach 主題 Bottom Navigation Bar 背景為碧綠色半透明
- 優化主題樣式分類邏輯
- 統一商業主題的 AppBar 和 Bottom Navigation Bar 樣式"

git push origin main
```

#### 1.3 主題設置頁面
```bash
# 主題設置頁面更新
git add lib/account/pages/theme_settings_page.dart
git commit -m "feat: 優化主題設置頁面

- 同步主題選項圓形背景色與預設主題
- 移除 Meta 主題下拉選單半透明效果
- 修復 Rainbow 主題返回箭頭顏色
- 更新 Morandi Lemon 顯示名稱為 Yellow"

git push origin main
```

#### 1.4 主題相關組件
```bash
# 主題相關組件更新
git add lib/widgets/color_selector.dart
git commit -m "feat: 更新顏色選擇器組件

- 修改 Morandi Lemon 短名稱為 Yellow
- 優化主題顏色顯示邏輯"

git push origin main
```

### 2. 因主題設置而調整的內容 (Theme-Dependent Adjustments)

#### 2.1 應用程序框架
```bash
# 應用程序框架更新
git add lib/layout/app_scaffold.dart
git commit -m "fix: 修復 AppBar UI 風格一致性

- 移除 AppBar BoxDecoration 中衝突的 color 屬性
- 簡化 _getBackArrowColor 邏輯
- 統一商業主題和玻璃態主題的返回箭頭顏色
- 確保 AppBar 背景漸層正確顯示"

git push origin main
```

#### 2.2 任務頁面調整
```bash
# 任務頁面背景調整
git add lib/task/pages/task_list_page.dart
git commit -m "fix: 任務頁面使用純白背景

- 設置 Scaffold backgroundColor 為 Colors.white
- 設置任務卡片背景為 Colors.white
- 設置下拉選單填充色為 Colors.white
- 確保任務頁面不受主題背景影響"

git push origin main
```

#### 2.3 錯誤頁面遷移
```bash
# 錯誤頁面主題服務遷移
git add lib/widgets/error_page.dart
git commit -m "refactor: 遷移錯誤頁面到新的主題配置管理器

- 將 Consumer<ThemeService> 改為 Consumer<ThemeConfigManager>
- 更新變量名從 themeService 到 themeManager
- 移除對已棄用 theme_service.dart 的依賴"

git push origin main
```

#### 2.4 任務申請頁面遷移
```bash
# 任務申請頁面主題服務遷移
git add lib/task/pages/task_apply_page.dart
git commit -m "refactor: 遷移任務申請頁面到新的主題配置管理器

- 將 Consumer<ThemeService> 改為 Consumer<ThemeConfigManager>
- 更新變量名從 themeService 到 themeManager
- 修復空值檢查邏輯"

git push origin main
```

#### 2.5 評分頁面遷移
```bash
# 評分頁面主題服務遷移
git add lib/account/pages/ratings_page.dart
git commit -m "refactor: 遷移評分頁面到新的主題配置管理器

- 移除對已刪除 theme_service.dart 的導入
- 保留對 theme_config_manager.dart 的正確導入
- 修復編譯錯誤"

git push origin main
```

## 批量推送指令

### 主題設置相關批量推送
```bash
# 一次性推送所有主題設置相關更改
git add lib/constants/theme_schemes.dart lib/services/theme_config_manager.dart lib/account/pages/theme_settings_page.dart lib/widgets/color_selector.dart
git commit -m "feat: 主題系統全面更新

主題配色方案:
- Beach Sunset 主題改為碧綠色系
- Ocean 主題背景漸層調整為更淡版本
- Rainbow 主題 Dark Mode 漸層調整為低飽和度偏暗
- Morandi Lemon 更名為 Yellow

主題管理:
- 優化主題配置管理器邏輯
- 統一商業主題 UI 風格
- 修復主題設置頁面顯示問題

組件更新:
- 同步主題選項圓形背景色
- 移除 Meta 主題下拉選單半透明效果
- 修復 Rainbow 主題返回箭頭顏色"

git push origin main
```

### 因主題設置而調整的內容批量推送
```bash
# 一次性推送所有因主題設置而調整的內容
git add lib/layout/app_scaffold.dart lib/task/pages/task_list_page.dart lib/widgets/error_page.dart lib/task/pages/task_apply_page.dart lib/account/pages/ratings_page.dart
git commit -m "fix: 因主題設置調整的 UI 組件

應用程序框架:
- 修復 AppBar UI 風格一致性問題
- 統一商業主題和玻璃態主題的返回箭頭顏色
- 確保 AppBar 背景漸層正確顯示

頁面調整:
- 任務頁面使用純白背景，不受主題影響
- 任務卡片和下拉選單使用白色背景

服務遷移:
- 將所有頁面從 ThemeService 遷移到 ThemeConfigManager
- 修復編譯錯誤和導入問題
- 移除對已棄用服務的依賴"

git push origin main
```

## 完整項目推送
```bash
# 推送所有主題相關更改
git add .
git commit -m "feat: 主題系統全面重構和優化

🎨 主題配色更新:
- Beach Sunset: 藍色系 → 碧綠色系
- Ocean: 背景漸層調整為更淡版本
- Rainbow: Dark Mode 漸層調整為低飽和度偏暗
- Morandi Lemon → Yellow

🔧 主題管理優化:
- 統一商業主題 UI 風格
- 修復 AppBar 和 Bottom Navigation Bar 一致性
- 優化主題配置管理器邏輯

📱 UI 組件調整:
- 任務頁面使用純白背景
- 同步主題選項圓形背景色
- 移除 Meta 主題下拉選單半透明效果
- 修復 Rainbow 主題返回箭頭顏色

🔄 服務遷移:
- 從 ThemeService 遷移到 ThemeConfigManager
- 修復所有編譯錯誤
- 清理已棄用的服務和文件

📁 項目結構整理:
- 創建文檔管理目錄
- 整理測試腳本和開發工具
- 統一管理非正式項目內容"

git push origin main
```

## 推送檢查清單

### 推送前檢查
- [ ] 所有主題相關文件已修改
- [ ] 編譯錯誤已修復
- [ ] 測試通過
- [ ] 文檔已更新

### 推送後驗證
- [ ] 主題切換功能正常
- [ ] AppBar 和 Bottom Navigation Bar 樣式一致
- [ ] 任務頁面背景正確
- [ ] 無編譯錯誤 