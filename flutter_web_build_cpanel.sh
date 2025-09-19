#!/bin/bash

# Flutter Web cPanel 部署建置腳本
# 解決 manifest.json 路徑問題

echo "🚀 開始 Flutter Web cPanel 部署建置..."

# 設定環境變數
export FLUTTER_BASE_HREF=/web/

# 建置 Flutter Web (生產環境)
echo "📦 建置 Flutter Web (生產環境)..."
flutter build web --release --base-href /web/ --dart-define=ENVIRONMENT=production

# 檢查建置結果
if [ $? -eq 0 ]; then
    echo "✅ Flutter Web 建置成功"
    
    # 檢查建置後的檔案
    echo "📁 檢查建置結果..."
    ls -la build/web/
    
    # 檢查 manifest.json 是否存在
    if [ -f "build/web/manifest.json" ]; then
        echo "✅ manifest.json 已生成"
        echo "📄 manifest.json 內容預覽:"
        head -5 build/web/manifest.json
    else
        echo "❌ manifest.json 未找到"
    fi
    
    # 檢查 index.html 中的 base href
    echo "🔍 檢查 index.html 中的 base href:"
    grep -n "base href" build/web/index.html
    
    # 檢查 manifest.json 引用
    echo "🔍 檢查 manifest.json 引用:"
    grep -n "manifest.json" build/web/index.html
    
else
    echo "❌ Flutter Web 建置失敗"
    exit 1
fi

echo "🎉 Flutter Web cPanel 部署建置完成！"
echo "📋 部署說明:"
echo "   1. 將 build/web/ 目錄內容複製到 public_html/web/"
echo "   2. 確保 manifest.json 在 public_html/web/manifest.json"
echo "   3. 訪問 https://yourdomain.com/web/ 測試"
