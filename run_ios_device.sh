#!/bin/bash

# Flutter iOS 真機開發腳本
# 自動抓取本機 IP，支援 Debug / Release / Profile / Attach 模式切換
# 
# 用法：
#   ./run_ios_device.sh                      # 預設: 真機=Mook，模式=profile
#   ./run_ios_device.sh "Mook"        # 指定真機，模式=profile
#   ./run_ios_device.sh "iPhone 16" debug   # 指定真機，模式=debug
#   ./run_ios_device.sh "iPhone 16" profile # 指定真機，模式=profile
#   ./run_ios_device.sh "iPhone 16" release # 指定真機，模式=release
#   ./run_ios_device.sh "iPhone 16" attach  # 連接到已運行的應用程式

# ==============================
# 參數設定
# ==============================
DEVICE=${1:-"Mook"}
MODE=${2:-"profile"}   # release | profile | debug | attach

echo "📱 啟動 iOS 真機開發環境..."
echo "🔧 目標設備: $DEVICE"
echo "🔧 模式: $MODE"

# ==============================
# 自動檢測本機 IP
# ==============================
# 自動檢測本機網路 IP 地址
LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

# 如果自動檢測失敗，使用預設值
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP="192.168.1.101"
    echo "⚠️  無法自動檢測 IP，使用預設值: $LOCAL_IP"
else
    echo "✅ 自動檢測到本機 IP: $LOCAL_IP"
fi

echo "💡 本機網路 IP 地址: $LOCAL_IP"
echo "⚠️  請確保真機與開發機器在同一網路"

# ==============================
# API 與 Socket 配置
# ==============================
API_ORIGIN="http://$LOCAL_IP:8888"
API_PREFIX="/here4help/backend/api"
API_BASE_URL="$API_ORIGIN/here4help/backend"
IMAGE_BASE_URL="$API_ORIGIN/here4help"
SOCKET_URL="http://$LOCAL_IP:3000"

# ==============================
# OAuth 參數
# ==============================
GOOGLE_CLIENT_ID="102744926949-bhrnm2970bgt3dfm2nmdbqt03mrvdh3i.apps.googleusercontent.com"
GOOGLE_IOS_CLIENT_ID="102744926949-951r2epiq93abijklu5te2qocpc9kqqv.apps.googleusercontent.com"
FACEBOOK_APP_ID="1037019294991326"
APPLE_SERVICE_ID="com.nccu.here4help.login"

# Redirect URIs
GOOGLE_REDIRECT_URI="$API_BASE_URL/api/auth/google-callback.php"
FACEBOOK_REDIRECT_URI="$API_BASE_URL/api/auth/facebook-callback.php"
APPLE_REDIRECT_URI="$API_BASE_URL/api/auth/apple-callback.php"

# iOS Apple 設定
APPLE_KEY_ID=""   # TODO: 補上你的 Key ID
APPLE_TEAM_ID="Q4C6BSB74K"

# ==============================
# 顯示環境
# ==============================
echo "📱 環境配置："
echo "  - API Origin: $API_ORIGIN"
echo "  - Socket URL: $SOCKET_URL"
echo "  - Environment: development"
echo "  - Debug Mode: $([ "$MODE" == "debug" ] && echo true || echo false)"
echo "  - Profile Mode: $([ "$MODE" == "profile" ] && echo true || echo false)"
echo "  - Attach Mode: $([ "$MODE" == "attach" ] && echo true || echo false)"
echo "  - iOS Deployment Target: 15.0+"
echo ""

# ==============================
# 檢查服務器狀態
# ==============================
echo "🔍 檢查本地服務器狀態..."

# 檢查 MAMP API 服務器 (本地)
LOCAL_API_URL="http://127.0.0.1:8888"
if curl -s --connect-timeout 3 "$LOCAL_API_URL" > /dev/null 2>&1; then
    echo "✅ MAMP API 服務器運行中: $LOCAL_API_URL"
    echo "   → iOS 真機將訪問: $API_ORIGIN"
else
    echo "⚠️ MAMP API 服務器未運行: $LOCAL_API_URL"
    echo "   請確保 MAMP 運行並允許外部訪問"
    echo "   iOS 真機需要訪問: $API_ORIGIN"
fi

# 檢查 Socket 服務器 (本地)
LOCAL_SOCKET_URL="http://127.0.0.1:3000"
if curl -s --connect-timeout 3 "$LOCAL_SOCKET_URL/health" > /dev/null 2>&1; then
    echo "✅ Socket 服務器運行中: $LOCAL_SOCKET_URL"
    echo "   → iOS 真機將訪問: $SOCKET_URL"
else
    echo "⚠️ Socket 服務器未運行: $LOCAL_SOCKET_URL"
    echo "   請執行: cd backend/socket && node server.js"
    echo "   iOS 真機需要訪問: $SOCKET_URL"
fi

echo ""

# ==============================
# 清理和準備 (Attach 模式跳過)
# ==============================
if [ "$MODE" != "attach" ]; then
    echo "🧹 清理項目緩存..."
    flutter clean
    flutter pub get

    echo "📱 準備 iOS 環境..."
    cd ios
    pod install
    cd ..
else
    echo "🔗 Attach 模式：跳過清理和編譯步驟"
fi

# ==============================
# 啟動 iOS 真機
# ==============================
if [ "$MODE" == "attach" ]; then
    echo "🔗 連接到已運行的 iOS 真機應用程式 ($DEVICE)..."
    flutter attach -d "$DEVICE"
else
    echo "🚀 啟動 iOS 真機 ($DEVICE) 模式=$MODE..."
    flutter run -d "$DEVICE" \
      --$MODE \
      --dart-define=ENVIRONMENT=development \
      --dart-define=APP_ENVIRONMENT=development \
      --dart-define=APP_DEBUG=$([ "$MODE" == "debug" ] && echo true || echo false) \
      --dart-define=IOS_SIMULATOR=false \
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
fi

echo ""
if [ "$MODE" == "attach" ]; then
    echo "✅ 已連接到 iOS 真機應用程式"
    echo "🔗 連接模式: $MODE"
else
    echo "✅ iOS 真機已啟動"
    echo "🚀 啟動模式: $MODE"
fi
echo "📱 環境: development"
