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

# 更新 pubspec.yaml 版本號（更新日期部分）
# 格式：主版本號.次版本號.修訂號+yyyymmddv
# v 是當天的建置次數（1, 2, 3...），同一天會遞增
update_version() {
  local pubspec_file="pubspec.yaml"
  
  if [ ! -f "$pubspec_file" ]; then
    echo "⚠️  警告：找不到 $pubspec_file，跳過版本號更新"
    return 0
  fi
  
  echo "📝 更新版本號..."
  
  # 讀取當前版本號
  local current_version=$(grep "^version:" "$pubspec_file" | sed 's/version: //' | tr -d ' ')
  
  if [ -z "$current_version" ]; then
    echo "⚠️  警告：無法讀取當前版本號，跳過更新"
    return 0
  fi
  
  # 解析版本號格式：主版本號.次版本號.修訂號+yyyymmddv
  # 例如：1.9.5+2025110915
  local version_part=$(echo "$current_version" | cut -d'+' -f1)
  local date_build_part=$(echo "$current_version" | cut -d'+' -f2)
  
  # 獲取今天的日期（格式：YYYYMMDD）
  local today
  if ! today=$(date +"%Y%m%d" 2>/dev/null); then
    echo "❌ 無法獲取當前日期，請檢查系統時間設定"
    return 1
  fi
  
  # 確保 today 變數有值
  if [ -z "$today" ]; then
    echo "❌ 日期變數為空，無法更新版本號"
    return 1
  fi
  
  # 提取當前版本號中的日期部分（前8位）
  local current_date=""
  local current_build_num=0
  
  if [ -n "$date_build_part" ] && [ ${#date_build_part} -ge 8 ]; then
    # 提取日期部分（前8位）
    current_date="${date_build_part:0:8}"
    # 提取建置號（第9位開始）
    local build_part="${date_build_part:8}"
    # 移除前導零並轉換為數字（如果 build_part 為空或非數字，設為 0）
    if [ -n "$build_part" ] && [[ "$build_part" =~ ^[0-9]+$ ]]; then
      current_build_num=$((10#$build_part))
    else
      current_build_num=0
    fi
  fi
  
  # 計算新的建置號
  local new_build_num=1
  if [ "$current_date" = "$today" ]; then
    echo "📅 偵測到今天已有建置版本，當前次數：v${current_build_num}"
    read -p "是否要將建置次數遞增 (+1)？(y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      new_build_num=$((current_build_num + 1))
    else
      new_build_num=$current_build_num
      if [ "$new_build_num" -le 0 ]; then
        new_build_num=1
      fi
      echo "ℹ️  保持原建置次數 v${new_build_num}"
    fi
  else
    # 如果是新的一天，建置號從 1 開始
    new_build_num=1
  fi
  
  # 組合新的日期+建置號（格式：yyyymmddv）
  local new_date_build="${today}${new_build_num}"
  
  # 組合新版本號
  local new_version="${version_part}+${new_date_build}"
  
  # 更新 pubspec.yaml
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS 使用 sed -i ''
    if ! sed -i '' "s/^version:.*/version: $new_version/" "$pubspec_file"; then
      echo "❌ 無法更新 pubspec.yaml，請檢查檔案權限"
      return 1
    fi
  else
    # Linux 使用 sed -i
    if ! sed -i "s/^version:.*/version: $new_version/" "$pubspec_file"; then
      echo "❌ 無法更新 pubspec.yaml，請檢查檔案權限"
      return 1
    fi
  fi
  
  echo "✅ 版本號已更新：$current_version → $new_version"
  echo "   📅 日期：${today}，建置次數：${new_build_num}"
  echo ""
  return 0
}

# 建置 iOS 應用程式
build_ios_app() {
  local build_mode=$1
  local environment=$2
  local app_debug=$3
  
  echo "🔨 建置 iOS $build_mode 版本..."
  
  if flutter build ios --$build_mode \
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
    --dart-define=APPLE_TEAM_ID=$APPLE_TEAM_ID; then
    echo "✅ iOS $build_mode 建置完成！"
    echo "📁 建置檔案位於: build/ios/iphoneos/"
    echo ""
    return 0
  else
    echo "❌ iOS $build_mode 建置失敗！"
    return 1
  fi
}

# 檢查 Xcode 進程（避免 PIF transfer session 錯誤）
check_xcode_processes() {
  echo "🔍 檢查 Xcode 進程..."
  
  local xcode_running=$(pgrep -x Xcode 2>/dev/null || true)
  
  if [ -n "$xcode_running" ]; then
    echo "⚠️  警告：偵測到 Xcode 正在運行"
    echo ""
    echo "Xcode 正在運行可能會導致以下問題："
    echo "- 無法進行 Product → Archive"
    echo "- 無法 Clean Build Folder"
    echo "- PIF transfer session 錯誤"
    echo ""
    echo "建議解決方案："
    echo "1. 關閉 Xcode"
    echo "2. 執行清理腳本: ./scripts/clean_xcode_cache.sh"
    echo "3. 重新開啟 Xcode 並嘗試 Archive"
    echo ""
    read -p "是否要關閉 Xcode 並繼續建置？(y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "🛑 關閉 Xcode..."
      killall Xcode 2>/dev/null || true
      sleep 2
      echo "✅ Xcode 已關閉"
    else
      echo "ℹ️  保持 Xcode 運行，繼續建置..."
      echo "⚠️  如果後續遇到 Archive 問題，請關閉 Xcode 後重試"
    fi
  else
    echo "✅ 沒有偵測到 Xcode 進程"
  fi
}

# 檢查 Code Signing 證書（Release 模式）
check_code_signing() {
  if [ "$MODE" = "release" ]; then
    echo "🔐 檢查 Code Signing 設定..."
    
    # 檢查是否有 Distribution 證書
    local team_id="Q4C6BSB74K"
    local certs=$(security find-identity -v -p codesigning 2>/dev/null | grep -i "distribution" | grep "$team_id" || true)
    
    if [ -z "$certs" ]; then
      echo "⚠️  警告：找不到 Team ID $team_id 的 iOS Distribution 證書"
      echo ""
      echo "請確認："
      echo "1. 已在 Apple Developer Portal 同意最新的 Program License Agreement"
      echo "2. 已在 Xcode 中設定 Signing & Capabilities"
      echo "3. 已選擇正確的 Team 和 Bundle Identifier"
      echo ""
      echo "查看所有證書："
      echo "  security find-identity -v -p codesigning"
      echo ""
      read -p "是否繼續建置？(y/N) " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 建置已取消"
        exit 1
      fi
    else
      echo "✅ 找到 Distribution 證書"
    fi
  fi
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
# 更新版本號
# ==============================
# 如果版本號更新失敗，詢問用戶是否繼續
if ! update_version; then
  echo ""
  echo "⚠️  版本號更新失敗！"
  echo ""
  read -p "是否要繼續建置流程？(y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ 建置已取消"
    exit 1
  fi
  echo "ℹ️  繼續建置流程（版本號未更新）..."
  echo ""
fi

# ==============================
# 清理 & 依賴
# ==============================
echo "🧹 清理專案..."
flutter clean
flutter pub get

# ==============================
# Xcode 進程檢查（避免 PIF 錯誤）
# ==============================
check_xcode_processes

# ==============================
# iOS 特定準備
# ==============================
prepare_ios_environment

# ==============================
# Code Signing 檢查（Release 模式）
# ==============================
check_code_signing

# ==============================
# 建置 iOS (依參數選擇)
# ==============================
BUILD_SUCCESS=false

case "$MODE" in
  debug)
    if build_ios_app "debug" "development" "true"; then
      BUILD_SUCCESS=true
    fi
    ;;
  release)
    if build_ios_app "release" "production" "false"; then
      BUILD_SUCCESS=true
    fi
    ;;
  simulator)
    if build_ios_app "debug" "ios_simulator" "true"; then
      BUILD_SUCCESS=true
    fi
    ;;
  all)
    if build_ios_app "debug" "development" "true" && \
       build_ios_app "release" "production" "false"; then
      BUILD_SUCCESS=true
    fi
    ;;
  *)
    echo "❌ 未知的建置模式: $MODE"
    echo "請使用 debug、release、simulator 或 all"
    exit 1
    ;;
esac

# ==============================
# 建置成功後啟動 Xcode
# ==============================
if [ "$BUILD_SUCCESS" = true ]; then
  echo "🚀 建置成功！正在啟動 Xcode..."
  open ios/Runner.xcworkspace
  echo "✅ Xcode 已啟動"
  echo ""
else
  echo "❌ 建置失敗，不會啟動 Xcode"
  exit 1
fi

echo "📋 Archive 部署步驟："
echo "1. 使用 Xcode 開啟 ios/Runner.xcworkspace"
echo "2. 確認 Signing & Capabilities 設定："
echo "   - 勾選 'Automatically manage signing'"
echo "   - 選擇正確的 Team (Q4C6BSB74K)"
echo "   - 確認 Bundle Identifier (com.example.here4help)"
echo "3. 選擇 'Any iOS Device' 或 'Generic iOS Device'"
echo "4. Product → Archive"
echo ""
echo "🔧 如果 Archive 失敗，請檢查："
echo "- 已在 Apple Developer Portal 同意最新的 PLA"
echo "- 有有效的 iOS Distribution 證書"
echo "- Xcode 中已登入正確的 Apple ID"
echo "- Xcode 已完全關閉（避免 PIF transfer session 錯誤）"
echo "- 查看詳細錯誤訊息：docs/IOS_ARCHIVE_TROUBLESHOOTING.md"
echo ""
echo "🚨 如果遇到 'PIF transfer session' 錯誤："
echo "  執行清理腳本: ./scripts/clean_xcode_cache.sh"
echo ""
echo "🔐 Code Signing 檢查："
echo "  security find-identity -v -p codesigning"
echo ""
echo "📝 用法說明："
echo "  ./build_ios.sh debug     # 僅建置 Debug (使用 .env.development)"
echo "  ./build_ios.sh release   # 僅建置 Release (使用 .env.production)"
echo "  ./build_ios.sh simulator # 建置 iOS 模擬器版本 (使用 .env.ios_simulator)"
echo "  ./build_ios.sh all       # 同時建置 Debug 與 Release"
