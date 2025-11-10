#!/bin/bash

# Admin Frontend Build Script
# 用於打包 Vue 前端到 admin/public

echo "🔨 開始打包 Admin Frontend..."

# 進入前端目錄
cd "$(dirname "$0")/frontend" || exit 1

# 檢查 node_modules 是否存在
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
  npm install @tiptap/vue-3 @tiptap/starter-kit @tiptap/extension-table @tiptap/extension-table-row @tiptap/extension-table-header @tiptap/extension-table-cell @tiptap/extension-underline @tiptap/extension-text-style @tiptap/extension-color
fi

# 打包生產版本
echo "🏗️  打包生產版本..."
npm run build

# 檢查打包結果
if [ -f "../public/index.html" ]; then
  echo "✅ 打包成功！"
  echo "📁 輸出目錄: admin/public/"
  echo "📄 入口文件: admin/public/index.html"
  ls -lh ../public/
else
  echo "❌ 打包失敗！"
  exit 1
fi

echo ""
echo "📋 部署步驟："
echo "1. 將 admin/ 目錄上傳到 cPanel"
echo "2. 設置文檔根目錄為 admin/public/"
echo "3. 配置 .env 文件"
echo "4. 運行 composer install --no-dev"
echo "5. 運行 php artisan key:generate"
echo "6. 運行 php artisan migrate"
