#!/bin/bash

# Flutter Web 建置腳本 - 針對 cPanel 部署優化
# 使用 dart-define 傳遞環境變數，避免敏感資訊打包進 assets

echo "🚀 開始建置 Flutter Web..."

# ==============================
# 共用變數設定
# ==============================
BASE_URL="https://hero4help.demofhs.com"
BACKEND_URL="$BASE_URL/backend"
WEB_PATH="/web/"

# OAuth 參數
GOOGLE_CLIENT_ID="102744926949-bhrnm2970bgt3dfm2nmdbqt03mrvdh3i.apps.googleusercontent.com"
FACEBOOK_APP_ID="1037019294991326"
APPLE_SERVICE_ID="com.nccu.here4help.login"

# Redirect URIs
GOOGLE_REDIRECT_URI="$BACKEND_URL/api/auth/google-callback.php"
FACEBOOK_REDIRECT_URI="$BACKEND_URL/api/auth/facebook-callback.php"
APPLE_REDIRECT_URI="$BACKEND_URL/api/auth/apple-callback.php"

# ==============================
# 清理 & 依賴
# ==============================
flutter clean
flutter pub get

# ==============================
# 建置 Web
# ==============================
flutter build web --release \
  --base-href $WEB_PATH \
  --dart-define=APP_ENVIRONMENT=production \
  --dart-define=APP_DEBUG=false \
  --dart-define=API_BASE_URL=$BACKEND_URL \
  --dart-define=API_ORIGIN=$BASE_URL \
  --dart-define=API_PREFIX=/backend/api \
  --dart-define=IMAGE_BASE_URL=$BASE_URL \
  --dart-define=SOCKET_URL=$BASE_URL \
  # /socket 透過 server.js 進行代理，使用 3001 端口
  --dart-define=GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID \
  --dart-define=GOOGLE_REDIRECT_URI=$GOOGLE_REDIRECT_URI \
  --dart-define=FACEBOOK_APP_ID=$FACEBOOK_APP_ID \
  --dart-define=FACEBOOK_REDIRECT_URI=$FACEBOOK_REDIRECT_URI \
  --dart-define=APPLE_SERVICE_ID=$APPLE_SERVICE_ID \
  --dart-define=APPLE_REDIRECT_URI=$APPLE_REDIRECT_URI \
  --pwa-strategy=none

echo "✅ Flutter Web 建置完成！"
echo "📁 建置檔案位於: build/web/"
echo ""
echo "📋 部署步驟："
echo "1. 將 build/web/ 內的所有檔案上傳到 cPanel 的 /public_html/web/ 目錄"
echo "2. 確保 .htaccess 檔案已正確設定"
echo "3. 測試網站: $BASE_URL/web/"