#!/bin/bash

# Flutter 全平台建置腳本
# 依序建置 Web、iOS、Android 版本

echo "🚀 開始建置 Flutter 全平台版本..."
echo "=========================================="

# ==============================
# 檢查環境
# ==============================
echo "🔍 檢查 Flutter 環境..."
flutter doctor

echo ""
echo "=========================================="

# ==============================
# 建置 Web 版本
# ==============================
echo "🌐 建置 Web 版本..."
if [ -f "build_web.sh" ]; then
    chmod +x build_web.sh
    ./build_web.sh
else
    echo "❌ build_web.sh 不存在"
fi

echo ""
echo "=========================================="

# ==============================
# 建置 iOS 版本
# ==============================
echo "🍎 建置 iOS 版本..."
if [ -f "build_ios.sh" ]; then
    chmod +x build_ios.sh
    ./build_ios.sh
else
    echo "❌ build_ios.sh 不存在"
fi

echo ""
echo "=========================================="

# ==============================
# 建置 Android 版本
# ==============================
echo "🤖 建置 Android 版本..."
if [ -f "build_android.sh" ]; then
    chmod +x build_android.sh
    ./build_android.sh
else
    echo "❌ build_android.sh 不存在"
fi

echo ""
echo "=========================================="
echo "🎉 全平台建置完成！"
echo ""
echo "📁 建置檔案位置："
echo "- Web: build/web/"
echo "- iOS: build/ios/iphoneos/"
echo "- Android APK: build/app/outputs/flutter-apk/"
echo "- Android AAB: build/app/outputs/bundle/release/"
echo ""
echo "📋 後續步驟："
echo "1. 檢查各平台的建置檔案"
echo "2. 進行測試和驗證"
echo "3. 部署到相應的商店或平台"
