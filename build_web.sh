#!/bin/bash

# Flutter Web 建置腳本 - 針對 cPanel 部署優化
# 使用 dart-define 傳遞環境變數，避免敏感資訊打包進 assets

echo "🚀 開始建置 Flutter Web..."

# 清理之前的建置
flutter clean
flutter pub get

# 建置 Web 版本
# - 使用 --dart-define 傳遞 API URL
# - 設定正確的 base-href
# - 關閉 PWA Service Worker (--pwa-strategy=none)
flutter build web --release \
  --base-href /web/ \
  --dart-define=API_BASE_URL=https://hero4help.demofhs.com/backend \
  --dart-define=API_ORIGIN=https://hero4help.demofhs.com \
  --dart-define=SOCKET_URL=wss://hero4help.demofhs.com:3001 \
  --pwa-strategy=none

echo "✅ Flutter Web 建置完成！"
echo "📁 建置檔案位於: build/web/"
echo ""
echo "📋 部署步驟："
echo "1. 將 build/web/ 內的所有檔案上傳到 cPanel 的 /public_html/web/ 目錄"
echo "2. 確保 .htaccess 檔案已正確設定"
echo "3. 測試網站: https://hero4help.demofhs.com/web/"
