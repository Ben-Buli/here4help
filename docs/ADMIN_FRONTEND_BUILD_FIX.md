# Admin Frontend 建置失敗問題修復報告

## 🔍 問題分析

根據錯誤訊息，有兩個主要問題：

### 1. Tailwind CSS v4 錯誤

**錯誤訊息：**
```
Error: Cannot apply unknown utility class `bg-white`. 
Are you using CSS modules or similar and missing `@reference`?
```

**原因：**
- Tailwind CSS v4 在 `<style scoped>` 中使用 `@apply` 時，需要先導入 Tailwind CSS
- 需要在 scoped style 的開頭添加 `@import "tailwindcss";`

**受影響的檔案：**
- `admin/frontend/src/components/content/PointPolicyEditor.vue`
- `admin/frontend/src/views/SupportChatDetailView.vue`
- `admin/frontend/src/views/SupportChatListView.vue`

### 2. 缺少依賴套件

**錯誤訊息：**
```
Rollup failed to resolve import "@tiptap/vue-3"
```

**原因：**
- `@tiptap/vue-3` 及其相關套件可能沒有正確安裝
- 雖然 `package.json` 中有定義，但 `node_modules` 中可能缺少

## ✅ 已完成的修復

### 1. 修復 Tailwind CSS v4 問題

**檔案：`admin/frontend/src/components/content/PointPolicyEditor.vue`**
```vue
<style scoped>
@import "tailwindcss";  // ✅ 新增

.toolbar-btn {
  @apply px-3 py-1.5 text-sm border rounded-md bg-white hover:bg-gray-100 ...;
}
...
</style>
```

**檔案：`admin/frontend/src/views/SupportChatDetailView.vue`**
```vue
<style scoped>
@import "tailwindcss";  // ✅ 新增

.admin-card {
  @apply bg-white shadow rounded-lg p-6;
}
...
</style>
```

**檔案：`admin/frontend/src/views/SupportChatListView.vue`**
```vue
<style scoped>
@import "tailwindcss";  // ✅ 新增

.admin-card {
  @apply bg-white shadow rounded-lg p-6;
}
...
</style>
```

### 2. 改善建置腳本

**檔案：`admin/build_admin_frontend.sh`**

新增功能：
- ✅ 即使 `node_modules` 存在也會執行 `npm install` 確保依賴最新
- ✅ 檢查關鍵依賴 `@tiptap/vue-3` 是否存在
- ✅ 如果缺少依賴，自動安裝所有 TipTap 相關套件

```bash
# 檢查並更新依賴
if [ ! -d "node_modules" ]; then
  echo "📦 安裝依賴..."
  npm install
else
  echo "📦 檢查並更新依賴..."
  npm install
fi

# 檢查關鍵依賴是否安裝
if [ ! -d "node_modules/@tiptap/vue-3" ]; then
  echo "⚠️  警告：@tiptap/vue-3 未安裝，重新安裝依賴..."
  npm install @tiptap/vue-3 @tiptap/starter-kit ...
fi
```

## 📋 執行步驟

### 步驟 1: 清理並重新安裝依賴

```bash
cd admin/frontend
rm -rf node_modules package-lock.json
npm install
```

### 步驟 2: 執行建置

```bash
cd ../..
./admin/build_admin_frontend.sh
```

### 步驟 3: 驗證建置結果

```bash
# 檢查輸出檔案
ls -lh admin/public/

# 應該看到：
# - index.html
# - assets/ 目錄
# - favicon.ico
```

## 🔧 如果仍有問題

### 檢查 Tailwind CSS 配置

確認 `admin/frontend/postcss.config.js` 正確：
```js
export default {
  plugins: {
    '@tailwindcss/postcss': {},
    autoprefixer: {},
  },
}
```

### 檢查 package.json 依賴

確認所有 TipTap 套件都在 `dependencies` 中：
```json
{
  "dependencies": {
    "@tiptap/vue-3": "^2.6.6",
    "@tiptap/starter-kit": "^2.6.6",
    "@tiptap/extension-table": "^2.6.6",
    "@tiptap/extension-table-cell": "^2.6.6",
    "@tiptap/extension-table-header": "^2.6.6",
    "@tiptap/extension-table-row": "^2.6.6",
    "@tiptap/extension-underline": "^2.6.6",
    "@tiptap/extension-text-style": "^2.6.6",
    "@tiptap/extension-color": "^2.6.6"
  }
}
```

### 手動安裝依賴

如果自動安裝失敗，可以手動執行：
```bash
cd admin/frontend
npm install @tiptap/vue-3 @tiptap/starter-kit @tiptap/extension-table @tiptap/extension-table-row @tiptap/extension-table-header @tiptap/extension-table-cell @tiptap/extension-underline @tiptap/extension-text-style @tiptap/extension-color
```

## 📝 注意事項

1. **Tailwind CSS v4 變更**
   - 在 scoped style 中使用 `@apply` 必須先導入 Tailwind
   - 使用 `@import "tailwindcss";` 而不是 `@tailwind` 指令

2. **依賴管理**
   - 確保所有 TipTap 套件版本一致（目前使用 ^2.6.6）
   - 如果升級 Tailwind CSS，可能需要調整語法

3. **建置環境**
   - 確保 Node.js 版本符合要求（^20.19.0 || >=22.12.0）
   - 確保 npm 版本是最新的

## ✅ 預期結果

修復後，建置應該：
- ✅ 成功編譯所有 Vue 組件
- ✅ 正確處理 Tailwind CSS 類別
- ✅ 正確打包 TipTap 編輯器
- ✅ 生成 `admin/public/index.html` 和相關資源檔案

