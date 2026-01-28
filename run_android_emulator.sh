#!/bin/bash

# Flutter Android 模擬器開發腳本
# 自動抓取本機 IP，支援 Debug / Release / Profile / Attach 模式切換
# 
# 用法：
#   ./run_android_emulator.sh                      # 預設: 模擬器=emulator-5554，模式=profile
#   ./run_android_emulator.sh "emulator-5554"      # 指定模擬器，模式=profile
#   ./run_android_emulator.sh "emulator-5554" debug   # 指定模擬器，模式=debug
#   ./run_android_emulator.sh "emulator-5554" profile # 指定模擬器，模式=profile
#   ./run_android_emulator.sh "emulator-5554" release # 指定模擬器，模式=release
#   ./run_android_emulator.sh "emulator-5554" attach  # 連接到已運行的應用程式

# ==============================
# 參數設定
# ==============================
DEVICE=${1:-"emulator-5554"}
MODE=${2:-"profile"}   # release | profile | debug | attach

echo "🤖 啟動 Android 模擬器開發環境..."
echo "🔧 目標設備: $DEVICE"
echo "🔧 模式: $MODE"

# ==============================
# Android 模擬器特殊 IP 配置
# ==============================
# Android 模擬器使用 10.0.2.2 來訪問主機的 localhost
# 這是 Android 模擬器的特殊 IP 地址
EMULATOR_HOST="10.0.2.2"

echo "💡 Android 模擬器主機 IP: $EMULATOR_HOST"
echo "   (模擬器使用 10.0.2.2 訪問主機的 localhost)"

# ==============================
# API 與 Socket 配置
# ==============================
API_ORIGIN="http://$EMULATOR_HOST:8888"
API_PREFIX="/here4help/backend/api"
API_BASE_URL="$API_ORIGIN/here4help/backend"
IMAGE_BASE_URL="$API_ORIGIN/here4help"
SOCKET_URL="http://$EMULATOR_HOST:3001"

# ==============================
# OAuth 參數
# ==============================
GOOGLE_CLIENT_ID="102744926949-bhrnm2970bgt3dfm2nmdbqt03mrvdh3i.apps.googleusercontent.com"
GOOGLE_ANDROID_CLIENT_ID="102744926949-u37cmuubvuvv8a1phetrih25qisk8fjo.apps.googleusercontent.com"
FACEBOOK_APP_ID="1037019294991326"
APPLE_SERVICE_ID="com.nccu.here4help.login"

# Redirect URIs
GOOGLE_REDIRECT_URI="$API_BASE_URL/api/auth/google-callback.php"
FACEBOOK_REDIRECT_URI="$API_BASE_URL/api/auth/facebook-callback.php"
APPLE_REDIRECT_URI="$API_BASE_URL/api/auth/apple-callback.php"

# Android 特定設定
ANDROID_KEYSTORE_PATH=""
ANDROID_KEYSTORE_PASSWORD=""
ANDROID_KEY_ALIAS=""
ANDROID_KEY_PASSWORD=""

# ==============================
# 顯示環境
# ==============================
echo "🤖 環境配置："
echo "  - API Origin: $API_ORIGIN"
echo "  - Socket URL: $SOCKET_URL"
echo "  - Environment: development"
echo "  - Debug Mode: $([ "$MODE" == "debug" ] && echo true || echo false)"
echo "  - Profile Mode: $([ "$MODE" == "profile" ] && echo true || echo false)"
echo "  - Attach Mode: $([ "$MODE" == "attach" ] && echo true || echo false)"
echo "  - Android Emulator: true"
echo "" 

# ==============================
# 檢查服務器狀態
# ==============================
echo "🔍 檢查本地服務器狀態..."

# 檢查 MAMP API 服務器 (本地)
LOCAL_API_URL="http://127.0.0.1:8888"
if curl -s --connect-timeout 3 "$LOCAL_API_URL" > /dev/null 2>&1; then
    echo "✅ MAMP API 服務器運行中: $LOCAL_API_URL"
    echo "   → Android 模擬器將通過 10.0.2.2 訪問: $API_ORIGIN"
else
    echo "⚠️ MAMP API 服務器未運行: $LOCAL_API_URL"
    echo "   請確保 MAMP 運行在 localhost:8888"
    echo "   Android 模擬器將通過 10.0.2.2 訪問: $API_ORIGIN"
fi

# 檢查 Socket 服務器 (本地)
LOCAL_SOCKET_URL="http://127.0.0.1:3000"
if curl -s --connect-timeout 3 "$LOCAL_SOCKET_URL/health" > /dev/null 2>&1; then
    echo "✅ Socket 服務器運行中: $LOCAL_SOCKET_URL"
    echo "   → Android 模擬器將通過 10.0.2.2 訪問: $SOCKET_URL"
else
    echo "⚠️ Socket 服務器未運行: $LOCAL_SOCKET_URL"
    echo "   請執行: cd backend/socket && node server.js"
    echo "   Android 模擬器將通過 10.0.2.2 訪問: $SOCKET_URL"
fi

echo ""

# ==============================
# 清理和準備 (Attach 模式跳過)
# ==============================
if [ "$MODE" != "attach" ]; then
  echo "🧹 準備項目..."
  
  # 檢查是否需要清理
  if [ ! -d "build" ] || [ ! -d ".dart_tool" ]; then
    echo "📦 首次運行，獲取依賴..."
    flutter pub get
  else
    echo "✅ 項目已準備就緒"
  fi

  echo "🤖 檢查 Android 環境..."
  # 檢查 Android 許可證（非阻塞）
  flutter doctor --android-licenses 2>/dev/null || echo "⚠️  Android 許可證檢查跳過"
  
  # 確保 Flutter 引擎文件完整
  echo "🔧 檢查 Flutter 引擎..."
  if ! flutter precache --android 2>/dev/null; then
    echo "⚠️  Flutter 引擎預緩存失敗，嘗試修復..."
    flutter doctor -v
    echo "💡 如果問題持續，請執行: flutter upgrade"
  fi
else
  echo "🔗 Attach 模式：跳過清理和編譯步驟"
fi

# ==============================
# 啟動 Android 模擬器
# ==============================
if [ "$MODE" == "attach" ]; then
    echo "🔗 連接到已運行的 Android 模擬器應用程式 ($DEVICE)..."
    flutter attach -d "$DEVICE"
else
    echo "🚀 啟動 Android 模擬器 ($DEVICE) 模式=$MODE..."
    flutter run -d "$DEVICE" \
      --$MODE \
      --dart-define=ENVIRONMENT=development \
      --dart-define=APP_ENVIRONMENT=development \
      --dart-define=APP_DEBUG=$([ "$MODE" == "debug" ] && echo true || echo false) \
      --dart-define=ANDROID_EMULATOR=true \
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
fi

echo ""
if [ "$MODE" == "attach" ]; then
    echo "✅ 已連接到 Android 模擬器應用程式"
    echo "🔗 連接模式: $MODE"
else
    echo "✅ Android 模擬器已啟動"
    echo "🚀 啟動模式: $MODE"
fi
echo "🤖 環境: development"
