# 文件管理系統指南

## 📁 **智能文件分類系統**

### 🎯 **分類原則**

#### 1. **當前活躍 (Current Active)**
- ✅ **保留在根目錄**
- 📋 **包含**：當前正在使用的標準、架構、計劃
- 🔄 **更新頻率**：定期更新
- 📌 **示例**：`API_ENDPOINT_STANDARDS.md`, `DATABASE_SCHEMA.md`

#### 2. **已完成功能 (Completed Features)**
- 📦 **歸檔到**：`archived/completed-features/`
- 📋 **包含**：已實現並完成的功能報告
- ✅ **狀態**：功能已上線，不再需要修改
- 📌 **示例**：`action_bar_implementation_summary.md`

#### 3. **Bug 修復 (Bug Fixes)**
- 🐛 **歸檔到**：`archived/bug-fixes/`
- 📋 **包含**：已修復的 Bug 報告
- ✅ **狀態**：問題已解決，保留作為參考
- 📌 **示例**：`android_debug_fix.md`

#### 4. **過時指南 (Deprecated Guides)**
- 📚 **歸檔到**：`archived/deprecated-guides/`
- 📋 **包含**：被新系統取代的配置指南
- ⚠️ **狀態**：不再適用，但保留歷史記錄
- 📌 **示例**：`GOOGLE_AUTH_SETUP.md`

#### 5. **舊報告 (Old Reports)**
- 📊 **歸檔到**：`archived/old-reports/`
- 📋 **包含**：過時的分析和架構報告
- 📈 **狀態**：已被新報告取代
- 📌 **示例**：`API_ARCHITECTURE_RECOMMENDATION.md`

#### 6. **被取代文檔 (Superseded Docs)**
- 🔄 **歸檔到**：`archived/superseded-docs/`
- 📋 **包含**：被新版本取代的文檔
- 🔄 **狀態**：有更新的版本
- 📌 **示例**：`CURSOR_TODO.md`

## 🛠️ **使用方式**

### 1. **自動分類**
```bash
# 執行智能分類腳本
./organize_docs.sh
```

### 2. **手動分類**
```bash
# 移動特定文件
mv "old_file.md" "archived/completed-features/"

# 創建新的分類目錄
mkdir -p "archived/new-category"
```

### 3. **檢查分類結果**
```bash
# 查看各分類目錄
ls -la archived/*/

# 搜索特定文件
find archived/ -name "*.md" | grep "keyword"
```

## 📋 **文件命名規範**

### 1. **當前活躍文件**
- ✅ 使用描述性名稱
- ✅ 包含版本或日期
- ✅ 使用英文命名
- 📌 示例：`API_ENDPOINT_STANDARDS.md`

### 2. **歸檔文件**
- 📦 保持原始名稱
- 📦 添加歸檔日期（可選）
- 📦 使用分類前綴（可選）
- 📌 示例：`completed-features/action_bar_implementation_summary.md`

## 🔄 **維護流程**

### 1. **定期清理 (每月)**
```bash
# 檢查是否有新文件需要分類
ls -la *.md | grep -E "(fix|summary|report|guide)"

# 執行分類
./organize_docs.sh
```

### 2. **新文件處理**
- 📝 **創建時**：直接放在適當的分類目錄
- 📝 **完成後**：移動到對應的歸檔目錄
- 📝 **更新時**：替換舊版本，歸檔舊版本

### 3. **清理檢查**
```bash
# 檢查重複文件
find . -name "*.md" -exec basename {} \; | sort | uniq -d

# 檢查空目錄
find archived/ -type d -empty

# 檢查大文件
find archived/ -name "*.md" -size +1M
```

## 📊 **分類統計**

### 當前分類統計
- 📦 **已完成功能**: 23 個文件
- 🐛 **Bug 修復**: 15 個文件
- 📚 **過時指南**: 13 個文件
- 📊 **舊報告**: 13 個文件
- 🔄 **被取代文檔**: 10 個文件
- ✅ **當前活躍**: 11 個文件

### 總計
- 📁 **總文件數**: 85+ 個文件
- 📦 **已歸檔**: 74 個文件
- ✅ **當前活躍**: 11 個文件

## 🎯 **最佳實踐**

### 1. **文件創建**
- ✅ 使用描述性標題
- ✅ 包含創建日期
- ✅ 添加相關標籤
- ✅ 包含狀態說明

### 2. **文件更新**
- 🔄 更新時保留版本歷史
- 🔄 標記更新日期
- 🔄 說明變更原因
- 🔄 歸檔舊版本

### 3. **文件歸檔**
- 📦 定期檢查文件狀態
- 📦 及時歸檔完成的工作
- 📦 保留重要的歷史記錄
- 📦 清理重複或無用文件

## 🚀 **自動化建議**

### 1. **Git Hooks**
```bash
# 在 .git/hooks/pre-commit 中添加
#!/bin/bash
# 檢查新文件是否需要分類
./organize_docs.sh --check-only
```

### 2. **定期任務**
```bash
# 每月執行一次完整清理
0 0 1 * * cd /path/to/docs && ./organize_docs.sh
```

### 3. **CI/CD 整合**
```yaml
# 在 CI/CD 中添加文件檢查
- name: Check Documentation Organization
  run: |
    cd docs
    ./organize_docs.sh --check-only
    if [ $? -ne 0 ]; then
      echo "Documentation needs organization"
      exit 1
    fi
```

## 🎉 **總結**

### 優勢
- ✅ **清晰的結構**：文件按狀態和類型分類
- ✅ **易於維護**：自動化分類和清理
- ✅ **歷史保留**：重要記錄不會丟失
- ✅ **查找效率**：快速定位相關文件

### 建議
- 🔄 **定期執行**：每月執行一次分類
- 🔄 **及時歸檔**：完成工作後立即歸檔
- 🔄 **保持更新**：定期更新當前活躍文件
- 🔄 **清理重複**：定期檢查和清理重複文件

**這個系統可以幫助您更好地管理專案文檔，保持 docs/ 目錄的整潔和效率！** 📁✨
