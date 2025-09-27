#!/bin/bash

# Flutter Android 建置腳本 - 針對 Google Play Store 部署優化
# 使用 dart-define 傳遞環境變數，避免敏感資訊打包進 assets

echo "🤖 開始建置 Flutter Android..."

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
GOOGLE_ANDROID_CLIENT_ID="102744926949-bhrnm2970bgt3dfm2nmdbqt03mrvdh3i.apps.googleusercontent.com"
FACEBOOK_APP_ID="1037019294991326"
APPLE_SERVICE_ID="com.nccu.here4help.login"

# Redirect URIs
GOOGLE_REDIRECT_URI="$BACKEND_URL/api/auth/google-callback.php"
FACEBOOK_REDIRECT_URI="$BACKEND_URL/api/auth/facebook-callback.php"
APPLE_REDIRECT_URI="$BACKEND_URL/api/auth/apple-callback.php"

# Android 特定設定
ANDROID_KEYSTORE_PATH=""
ANDROID_KEYSTORE_PASSWORD=""
ANDROID_KEY_ALIAS=""
ANDROID_KEY_PASSWORD=""

# ==============================
# 清理 & 依賴
# ==============================
echo "🧹 清理專案..."
flutter clean
flutter pub get

# ==============================
# Android 特定準備
# ==============================
echo "📱 準備 Android 環境..."
flutter doctor --android-licenses

# ==============================
# 建置 Android APK (Debug)
# ==============================
echo "🔨 建置 Android APK Debug 版本..."
flutter build apk --debug \
  --dart-define=APP_ENVIRONMENT=production \
  --dart-define=APP_DEBUG=false \
  --dart-define=API_BASE_URL=$API_BASE_URL \
  --dart-define=API_ORIGIN=$API_ORIGIN \
  --dart-define=API_PREFIX=$API_PREFIX \
  --dart-define=IMAGE_BASE_URL=$IMAGE_BASE_URL \
  --dart-define=SOCKET_URL=$SOCKET_URL \
  --dart-define=GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID \
  --dart-define=GOOGLE_ANDROID_CLIENT_ID=$GOOGLE_ANDROID_CLIENT_ID \
  --dart-define=GOOGLE_REDIRECT_URI=$GOOGLE_REDIRECT_URI \
  --dart-define=FACEBOOK_APP_ID=$FACEBOOK_APP_ID \
  --dart-define=FACEBOOK_REDIRECT_URI=$FACEBOOK_REDIRECT_URI \
  --dart-define=APPLE_SERVICE_ID=$APPLE_SERVICE_ID \
  --dart-define=APPLE_REDIRECT_URI=$APPLE_REDIRECT_URI

echo "✅ Android APK Debug 建置完成！"
echo "📁 建置檔案位於: build/app/outputs/flutter-apk/"
echo ""

# ==============================
# 建置 Android APK (Release)
# ==============================
echo "🔨 建置 Android APK Release 版本..."
flutter build apk --release \
  --dart-define=APP_ENVIRONMENT=production \
  --dart-define=APP_DEBUG=false \
  --dart-define=API_BASE_URL=$API_BASE_URL \
  --dart-define=API_ORIGIN=$API_ORIGIN \
  --dart-define=API_PREFIX=$API_PREFIX \
  --dart-define=IMAGE_BASE_URL=$IMAGE_BASE_URL \
  --dart-define=SOCKET_URL=$SOCKET_URL \
  --dart-define=GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID \
  --dart-define=GOOGLE_ANDROID_CLIENT_ID=$GOOGLE_ANDROID_CLIENT_ID \
  --dart-define=GOOGLE_REDIRECT_URI=$GOOGLE_REDIRECT_URI \
  --dart-define=FACEBOOK_APP_ID=$FACEBOOK_APP_ID \
  --dart-define=FACEBOOK_REDIRECT_URI=$FACEBOOK_REDIRECT_URI \
  --dart-define=APPLE_SERVICE_ID=$APPLE_SERVICE_ID \
  --dart-define=APPLE_REDIRECT_URI=$APPLE_REDIRECT_URI

echo "✅ Android APK Release 建置完成！"
echo "📁 建置檔案位於: build/app/outputs/flutter-apk/"
echo ""

# ==============================
# 建置 Android App Bundle (AAB) - 用於 Google Play Store
# ==============================
echo "🔨 建置 Android App Bundle (AAB)..."
flutter build appbundle --release \
  --dart-define=APP_ENVIRONMENT=production \
  --dart-define=APP_DEBUG=false \
  --dart-define=API_BASE_URL=$API_BASE_URL \
  --dart-define=API_ORIGIN=$API_ORIGIN \
  --dart-define=API_PREFIX=$API_PREFIX \
  --dart-define=IMAGE_BASE_URL=$IMAGE_BASE_URL \
  --dart-define=SOCKET_URL=$SOCKET_URL \
  --dart-define=GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID \
  --dart-define=GOOGLE_ANDROID_CLIENT_ID=$GOOGLE_ANDROID_CLIENT_ID \
  --dart-define=GOOGLE_REDIRECT_URI=$GOOGLE_REDIRECT_URI \
  --dart-define=FACEBOOK_APP_ID=$FACEBOOK_APP_ID \
  --dart-define=FACEBOOK_REDIRECT_URI=$FACEBOOK_REDIRECT_URI \
  --dart-define=APPLE_SERVICE_ID=$APPLE_SERVICE_ID \
  --dart-define=APPLE_REDIRECT_URI=$APPLE_REDIRECT_URI

echo "✅ Android App Bundle 建置完成！"
echo "📁 建置檔案位於: build/app/outputs/bundle/release/"
echo ""
echo "📋 部署步驟："
echo "1. APK 檔案可直接安裝到 Android 設備"
echo "2. AAB 檔案用於上傳到 Google Play Console"
echo "3. 確保已設定正確的簽名金鑰"
echo "4. 檢查 android/app/build.gradle 中的版本號"
echo ""
echo "🔧 注意事項："
echo "- 確保已安裝 Android SDK 和 Flutter"
echo "- 需要有效的 Google Play Developer 帳號"
echo "- 檢查 android/app/src/main/AndroidManifest.xml 中的權限"
echo "- 確認 google-services.json 已正確配置"
echo "- 建議使用 AAB 格式上傳到 Google Play Store"
