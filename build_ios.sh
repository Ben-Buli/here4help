#!/bin/bash

set -euo pipefail

# Flutter iOS 建置腳本 - 針對 App Store 部署優化
# 使用 dart-define 傳遞環境變數，避免敏感資訊打包進 assets
# ./build_ios.sh debug → 只建置 Debug
# ./build_ios.sh release → 只建置 Release (預設)
# ./build_ios.sh all → 同時建置 Debug 與 Release
# ./build_ios.sh simulator → 建置 iOS 模擬器版本

MODE=${1:-}
if [ -z "$MODE" ]; then
  MODE="release"
fi

echo "🍎 開始建置 Flutter iOS (模式: $MODE)..."

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
GOOGLE_IOS_CLIENT_ID="102744926949-951r2epiq93abijklu5te2qocpc9kqqv.apps.googleusercontent.com"
FACEBOOK_APP_ID="fb1037019294991326"
APPLE_SERVICE_ID="com.nccu.here4help.login"

# Redirect URIs
GOOGLE_REDIRECT_URI="$BACKEND_URL/api/auth/google-callback.php"
FACEBOOK_REDIRECT_URI="$BACKEND_URL/api/auth/facebook-callback.php"
APPLE_REDIRECT_URI="$BACKEND_URL/api/auth/apple-callback.php"

# iOS 特定設定
APPLE_KEY_ID=""
APPLE_TEAM_ID=""

# 根據建置模式設定環境特定的變數
case "$MODE" in
  debug)
    SOCKET_URL="http://127.0.0.1:3000"
    API_ORIGIN="http://localhost:8888"
    ;;
  simulator)
    SOCKET_URL="http://127.0.0.1:3000"
    API_ORIGIN="http://127.0.0.1:8888"
    ;;
  release)
    SOCKET_URL="$BASE_URL/socket"
    API_ORIGIN="$BASE_URL"
    ;;
esac

# 🚨 防呆檢查：Release 模式不能使用 localhost
if [ "$MODE" = "release" ] && [[ "$API_ORIGIN" == *"localhost"* ]]; then
  echo "❌ Release 模式不能使用 localhost，請檢查設定！"
  exit 1
fi

# ==============================
# 函數定義
# ==============================

# 建置 iOS 應用程式
build_ios_app() {
  local build_mode=$1
  local environment=$2
  local app_debug=$3
  
  echo "🔨 建置 iOS $build_mode 版本..."
  
  flutter build ios --$build_mode \
    --dart-define=ENVIRONMENT=$environment \
    --dart-define=APP_DEBUG=$app_debug \
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
  
  echo "✅ iOS $build_mode 建置完成！"
  echo "📁 建置檔案位於: build/ios/iphoneos/"
  echo ""
}

# 準備 iOS 環境
prepare_ios_environment() {
  echo "📱 準備 iOS 環境..."
  # 確保 pod install 以 UTF-8 執行，避免 Encoding::CompatibilityError
  export LANG="${LANG:-en_US.UTF-8}"
  export LC_ALL="${LC_ALL:-en_US.UTF-8}"
  cd ios
  if ! pod install; then
    echo "❌ pod install 失敗，請檢查輸出訊息"
    exit 1
  fi
  cd ..
}

# ==============================
# 清理 & 依賴
# ==============================
echo "🧹 清理專案..."
flutter clean
flutter pub get

# ==============================
# iOS 特定準備
# ==============================
prepare_ios_environment

# ==============================
# 建置 iOS (依參數選擇)
# ==============================
case "$MODE" in
  debug)
    build_ios_app "debug" "development" "true"
    ;;
  release)
    build_ios_app "release" "production" "false"
    ;;
  simulator)
    build_ios_app "debug" "ios_simulator" "true"
    ;;
  all)
    build_ios_app "debug" "development" "true"
    build_ios_app "release" "production" "false"
    ;;
  *)
    echo "❌ 未知的建置模式: $MODE"
    echo "請使用 debug、release、simulator 或 all"
    exit 1
    ;;
esac

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
echo ""
echo "📝 用法說明："
echo "  ./build_ios.sh debug     # 僅建置 Debug (使用 .env.development)"
echo "  ./build_ios.sh release   # 僅建置 Release (使用 .env.production)"
echo "  ./build_ios.sh simulator # 建置 iOS 模擬器版本 (使用 .env.ios_simulator)"
echo "  ./build_ios.sh all       # 同時建置 Debug 與 Release"
