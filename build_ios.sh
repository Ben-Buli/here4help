#!/bin/bash

# Flutter iOS 建置腳本 - 針對 App Store 部署優化
# 使用 dart-define 傳遞環境變數，避免敏感資訊打包進 assets

echo "🍎 開始建置 Flutter iOS..."

# ==============================
# 共用變數設定
# ==============================
BASE_URL="https://hero4help.demofhs.com"
BACKEND_URL="$BASE_URL/backend"
API_BASE_URL="$BACKEND_URL"
API_ORIGIN="$BASE_URL"
API_PREFIX="/backend/api"
IMAGE_BASE_URL="$BASE_URL"
SOCKET_URL="$BASE_URL"

# OAuth 參數
GOOGLE_CLIENT_ID="102744926949-bhrnm2970bgt3dfm2nmdbqt03mrvdh3i.apps.googleusercontent.com"
GOOGLE_IOS_CLIENT_ID="102744926949-bhrnm2970bgt3dfm2nmdbqt03mrvdh3i.apps.googleusercontent.com"
FACEBOOK_APP_ID="1037019294991326"
APPLE_SERVICE_ID="com.nccu.here4help.login"

# Redirect URIs
GOOGLE_REDIRECT_URI="$BACKEND_URL/api/auth/google-callback.php"
FACEBOOK_REDIRECT_URI="$BACKEND_URL/api/auth/facebook-callback.php"
APPLE_REDIRECT_URI="$BACKEND_URL/api/auth/apple-callback.php"

# iOS 特定設定
APPLE_KEY_ID=""
APPLE_TEAM_ID=""

# ==============================
# 清理 & 依賴
# ==============================
echo "🧹 清理專案..."
flutter clean
flutter pub get

# ==============================
# iOS 特定準備
# ==============================
echo "📱 準備 iOS 環境..."
cd ios
pod install
cd ..

# ==============================
# 建置 iOS (Debug)
# ==============================
echo "🔨 建置 iOS Debug 版本..."
flutter build ios --debug \
  --dart-define=APP_ENVIRONMENT=production \
  --dart-define=APP_DEBUG=false \
  --dart-define=API_BASE_URL=$API_BASE_URL \
  --dart-define=API_ORIGIN=$API_ORIGIN \
  --dart-define=API_PREFIX=$API_PREFIX \
  --dart-define=IMAGE_BASE_URL=$IMAGE_BASE_URL \
  --dart-define=SOCKET_URL=$SOCKET_URL \
  --dart-define=GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID \
  --dart-define=GOOGLE_IOS_CLIENT_ID=$GOOGLE_IOS_CLIENT_ID \
  --dart-define=GOOGLE_REDIRECT_URI=$GOOGLE_REDIRECT_URI \
  --dart-define=FACEBOOK_APP_ID=$FACEBOOK_APP_ID \
  --dart-define=FACEBOOK_REDIRECT_URI=$FACEBOOK_REDIRECT_URI \
  --dart-define=APPLE_SERVICE_ID=$APPLE_SERVICE_ID \
  --dart-define=APPLE_REDIRECT_URI=$APPLE_REDIRECT_URI \
  --dart-define=APPLE_KEY_ID=$APPLE_KEY_ID \
  --dart-define=APPLE_TEAM_ID=$APPLE_TEAM_ID

echo "✅ iOS Debug 建置完成！"
echo "📁 建置檔案位於: build/ios/iphoneos/"
echo ""

# ==============================
# 建置 iOS (Release)
# ==============================
echo "🔨 建置 iOS Release 版本..."
flutter build ios --release \
  --dart-define=APP_ENVIRONMENT=production \
  --dart-define=APP_DEBUG=false \
  --dart-define=API_BASE_URL=$API_BASE_URL \
  --dart-define=API_ORIGIN=$API_ORIGIN \
  --dart-define=API_PREFIX=$API_PREFIX \
  --dart-define=IMAGE_BASE_URL=$IMAGE_BASE_URL \
  --dart-define=SOCKET_URL=$SOCKET_URL \
  --dart-define=GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID \
  --dart-define=GOOGLE_IOS_CLIENT_ID=$GOOGLE_IOS_CLIENT_ID \
  --dart-define=GOOGLE_REDIRECT_URI=$GOOGLE_REDIRECT_URI \
  --dart-define=FACEBOOK_APP_ID=$FACEBOOK_APP_ID \
  --dart-define=FACEBOOK_REDIRECT_URI=$FACEBOOK_REDIRECT_URI \
  --dart-define=APPLE_SERVICE_ID=$APPLE_SERVICE_ID \
  --dart-define=APPLE_REDIRECT_URI=$APPLE_REDIRECT_URI \
  --dart-define=APPLE_KEY_ID=$APPLE_KEY_ID \
  --dart-define=APPLE_TEAM_ID=$APPLE_TEAM_ID

echo "✅ iOS Release 建置完成！"
echo "📁 建置檔案位於: build/ios/iphoneos/"
echo ""
echo "📋 部署步驟："
echo "1. 使用 Xcode 開啟 ios/Runner.xcworkspace"
echo "2. 選擇正確的 Team 和 Bundle Identifier"
echo "3. 設定 Code Signing"
echo "4. 選擇目標設備或模擬器"
echo "5. 點擊 Run 或 Archive 進行部署"
echo ""
echo "🔧 注意事項："
echo "- 確保已安裝 Xcode 和 iOS 開發工具"
echo "- 需要有效的 Apple Developer 帳號"
echo "- 檢查 ios/Runner/Info.plist 中的權限設定"
echo "- 確認 GoogleService-Info.plist 已正確配置"
