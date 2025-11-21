#!/bin/bash

# Flutter Android 建置腳本 - 針對 Google Play Store 部署優化
# 使用 dart-define 傳遞環境變數，避免敏感資訊打包進 assets
# ./build_android.sh debug → 只建置 Debug
# ./build_android.sh release → 只建置 Release (預設)
# ./build_android.sh all → 同時建置 Debug 與 Release
# ./build_android.sh emulator → 建置 Android 模擬器版本

MODE=$1
if [ -z "$MODE" ]; then
  MODE="release"
fi

echo "🤖 開始建置 Flutter Android (模式: $MODE)..."

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
GOOGLE_ANDROID_CLIENT_ID="102744926949-u37cmuubvuvv8a1phetrih25qisk8fjo.apps.googleusercontent.com"
FACEBOOK_APP_ID="fb1037019294991326"
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
# 函數定義
# ==============================

# 建置 Android APK
build_android_apk() {
  local build_mode=$1
  local environment=$2
  local app_debug=$3
  
  echo "🔨 建置 Android APK $build_mode 版本..."
  
  if flutter build apk --$build_mode \
    --dart-define=ENVIRONMENT=$environment \
    --dart-define=APP_DEBUG=$app_debug \
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
    --dart-define=APPLE_REDIRECT_URI=$APPLE_REDIRECT_URI; then
    echo "✅ Android APK $build_mode 建置完成！"
    echo "📁 建置檔案位於: build/app/outputs/flutter-apk/"
    echo ""
    return 0
  else
    echo "❌ Android APK $build_mode 建置失敗！"
    return 1
  fi
}

# 建置 Android App Bundle
build_android_bundle() {
  local environment=$1
  local app_debug=$2
  
  echo "🔨 建置 Android App Bundle (AAB)..."
  
  if flutter build appbundle --release \
    --dart-define=ENVIRONMENT=$environment \
    --dart-define=APP_DEBUG=$app_debug \
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
    --dart-define=APPLE_REDIRECT_URI=$APPLE_REDIRECT_URI; then
    echo "✅ Android App Bundle 建置完成！"
    echo "📁 建置檔案位於: build/app/outputs/bundle/release/"
    echo ""
    return 0
  else
    echo "❌ Android App Bundle 建置失敗！"
    return 1
  fi
}

# 準備 Android 環境
prepare_android_environment() {
  echo "📱 準備 Android 環境..."
  flutter doctor --android-licenses
}

# 開啟輸出資料夾
open_output_folder() {
  local folder_path=$1
  local folder_name=$2
  
  if [ -d "$folder_path" ]; then
    echo "📂 開啟 $folder_name 資料夾..."
    open "$folder_path"
    echo "✅ 已開啟: $folder_path"
  else
    echo "⚠️  警告：資料夾不存在: $folder_path"
  fi
}

# ==============================
# 清理 & 依賴
# ==============================
echo "🧹 清理專案..."
flutter clean
flutter pub get

# ==============================
# Android 特定準備
# ==============================
prepare_android_environment

# ==============================
# 建置 Android (依參數選擇)
# ==============================
BUILD_SUCCESS=false
APK_BUILT=false
AAB_BUILT=false

case "$MODE" in
  debug)
    if build_android_apk "debug" "development" "true"; then
      BUILD_SUCCESS=true
      APK_BUILT=true
    fi
    ;;
  release)
    if build_android_apk "release" "production" "false"; then
      APK_BUILT=true
      BUILD_SUCCESS=true
    fi
    if build_android_bundle "production" "false"; then
      AAB_BUILT=true
      BUILD_SUCCESS=true
    fi
    ;;
  emulator)
    if build_android_apk "debug" "android_emulator" "true"; then
      BUILD_SUCCESS=true
      APK_BUILT=true
    fi
    ;;
  all)
    if build_android_apk "debug" "development" "true" && \
       build_android_apk "release" "production" "false" && \
       build_android_bundle "production" "false"; then
      BUILD_SUCCESS=true
      APK_BUILT=true
      AAB_BUILT=true
    fi
    ;;
  *)
    echo "❌ 未知的建置模式: $MODE"
    echo "請使用 debug、release、emulator 或 all"
    exit 1
    ;;
esac

# ==============================
# 建置成功後開啟輸出資料夾
# ==============================
if [ "$BUILD_SUCCESS" = true ]; then
  echo ""
  echo "🚀 建置成功！正在開啟輸出資料夾..."
  
  # 開啟 APK 資料夾（如果有建置成功）
  if [ "$APK_BUILT" = true ]; then
    open_output_folder "build/app/outputs/flutter-apk" "APK 輸出"
  fi
  
  # 開啟 AAB 資料夾（如果有建置成功）
  if [ "$AAB_BUILT" = true ]; then
    sleep 1  # 稍微延遲，避免同時開啟太多視窗
    open_output_folder "build/app/outputs/bundle/release" "AAB 輸出"
  fi
  
  echo ""
else
  echo ""
  echo "❌ 所有建置都失敗，不會開啟輸出資料夾"
  exit 1
fi
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
echo ""
echo "📝 用法說明："
echo "  ./build_android.sh debug     # 僅建置 Debug (使用 .env.development)"
echo "  ./build_android.sh release   # 僅建置 Release (使用 .env.production)"
echo "  ./build_android.sh emulator  # 建置 Android 模擬器版本 (使用 .env.android_emulator)"
echo "  ./build_android.sh all       # 同時建置 Debug 與 Release"
