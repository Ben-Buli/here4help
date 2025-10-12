#!/bin/bash

# 清理認證資料腳本
# 用於清除 SharedPreferences 中的殘留認證資料

echo "🧹 清理認證資料..."

# 清理 Flutter 應用緩存
echo "📱 清理 Flutter 應用緩存..."
flutter clean

# 清理 iOS 模擬器資料
echo "🍎 清理 iOS 模擬器資料..."
xcrun simctl erase all

# 清理 Android 模擬器資料（如果存在）
echo "🤖 清理 Android 模擬器資料..."
if command -v adb &> /dev/null; then
    adb shell pm clear com.example.here4help 2>/dev/null || echo "Android 應用未安裝或無法清理"
fi

echo "✅ 認證資料清理完成！"
echo ""
echo "💡 現在重新啟動應用程式，應該會顯示登入頁面"
echo "🚀 執行: ./run_ios_simulator.sh 或 ./run_ios_device.sh"
