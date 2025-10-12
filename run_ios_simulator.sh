#!/bin/bash

# Flutter iOS 模擬器開發腳本
# 使用與 cPanel 部署一致的 dart-define 方式，避免 .env 檔案載入問題
# 專門針對 iOS 模擬器環境優化
# 
# 用法：
#   ./run_ios_simulator.sh                    # 使用預設模擬器 (iPhone 16)
#   ./run_ios_simulator.sh "iPhone 14 Pro"   # 指定模擬器設備

# 設定模擬器設備
DEFAULT_DEVICE="iPhone 16"
if [ -z "$1" ]; then
  # 偵測是否有多個 iPhone 16
  MATCHING_DEVICES=$(xcrun simctl list devices | grep "$DEFAULT_DEVICE" | grep -v "unavailable")
  if [ $(echo "$MATCHING_DEVICES" | wc -l) -gt 1 ]; then
    # 優先選擇 Booted 的 UUID 用於 simctl boot
    BOOTED_ID=$(echo "$MATCHING_DEVICES" | grep "(Booted)" | awk -F '[()]' '{print $2}')
    if [ -n "$BOOTED_ID" ]; then
      DEVICE=$BOOTED_ID
      DEVICE_NAME=$DEFAULT_DEVICE
      echo "⚡ 偵測到多個 $DEFAULT_DEVICE，Booted UUID: $DEVICE，flutter run 將使用設備名稱: $DEVICE_NAME"
    else
      # 沒有 Booted 的就用第一個 UUID 用於 simctl boot
      FIRST_ID=$(echo "$MATCHING_DEVICES" | head -n 1 | awk -F '[()]' '{print $2}')
      DEVICE=$FIRST_ID
      DEVICE_NAME=$DEFAULT_DEVICE
      echo "⚡ 偵測到多個 $DEFAULT_DEVICE，使用第一個 UUID: $DEVICE，flutter run 將使用設備名稱: $DEVICE_NAME"
    fi
  else
    DEVICE_NAME=$DEFAULT_DEVICE
    DEVICE=$DEFAULT_DEVICE
  fi
else
  DEVICE_NAME=$1
  DEVICE=$1
fi

echo "🍎 啟動 iOS 模擬器開發環境..."
echo "📱 目標設備 (flutter run 使用): $DEVICE_NAME"

# ==============================
# iOS 模擬器環境變數設定
# ==============================

# 本機開發 API 配置
API_ORIGIN="http://127.0.0.1:8888"
API_PREFIX="/here4help/backend/api"
API_BASE_URL="$API_ORIGIN/here4help/backend"
IMAGE_BASE_URL="$API_ORIGIN/here4help"

# 本機 Socket 配置（統一使用端口 3000）
SOCKET_URL="http://127.0.0.1:3000"

# OAuth 參數（與生產環境一致）
GOOGLE_CLIENT_ID="102744926949-bhrnm2970bgt3dfm2nmdbqt03mrvdh3i.apps.googleusercontent.com"
GOOGLE_IOS_CLIENT_ID="102744926949-951r2epiq93abijklu5te2qocpc9kqqv.apps.googleusercontent.com"
FACEBOOK_APP_ID="fb1037019294991326"
APPLE_SERVICE_ID="com.nccu.here4help.login"

# Redirect URIs（本機開發）
GOOGLE_REDIRECT_URI="$API_BASE_URL/api/auth/google-callback.php"
FACEBOOK_REDIRECT_URI="$API_BASE_URL/api/auth/facebook-callback.php"
APPLE_REDIRECT_URI="$API_BASE_URL/api/auth/apple-callback.php"

# iOS 特定設定
APPLE_KEY_ID=""
APPLE_TEAM_ID=""

echo "📱 環境配置："
echo "  - API Origin: $API_ORIGIN"
echo "  - Socket URL: $SOCKET_URL"
echo "  - Environment: ios_simulator"
echo "  - Debug Mode: true"
echo ""

# ==============================
# 檢查本機服務器狀態
# ==============================
echo "🔍 檢查本機服務器狀態..."

# 檢查 API 服務器（MAMP）
if curl -s --connect-timeout 3 "$API_ORIGIN" > /dev/null 2>&1; then
    echo "✅ API 服務器運行中: $API_ORIGIN"
else
    echo "⚠️ API 服務器未運行: $API_ORIGIN"
    echo "   請確保 MAMP 或其他本機服務器已啟動"
fi

# 檢查 Socket 服務器
if curl -s --connect-timeout 3 "$SOCKET_URL/health" > /dev/null 2>&1; then
    echo "✅ Socket 服務器運行中: $SOCKET_URL"
else
    echo "⚠️ Socket 服務器未運行: $SOCKET_URL"
    echo "   請執行: cd backend/socket && node server.js"
fi

echo ""

# ==============================
# 啟動 iOS 模擬器
# ==============================
echo "🚀 啟動 iOS 模擬器..."

# 使用 dart-define 方式傳遞環境變數（與 cPanel 部署一致）
# 使用 development 環境避免載入 .env.ios_simulator 檔案
flutter run -d "$DEVICE_NAME" \
  --dart-define=ENVIRONMENT=development \
  --dart-define=APP_DEBUG=true \
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

echo ""
echo "✅ iOS 模擬器開發環境已啟動"
echo "🔧 使用與 cPanel 一致的 dart-define 配置方式"
echo "📱 環境: ios_simulator"
echo "🐛 Debug 模式: 已啟用"
echo ""
echo "💡 提示："
echo "  - 確保 MAMP 服務器運行在 localhost:8888"
echo "  - 確保 Socket 服務器運行在 localhost:3000"
echo "  - 如需更換模擬器：./run_ios_simulator.sh \"iPhone 14 Pro\""
echo ""
echo "📋 可用的模擬器設備："
echo "  - iPhone 16 (預設)"
echo "  - Mook (真機)"
echo ""
echo "🔍 查看所有設備：flutter devices"
