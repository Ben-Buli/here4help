#!/bin/bash
# 查找最新的 APK 文件

echo "🔍 搜尋 APK 文件..."
echo ""

# 查找所有 APK 文件
APK_FILES=$(find build/app/outputs/flutter-apk -name "*.apk" -type f 2>/dev/null)

if [ -z "$APK_FILES" ]; then
    echo "❌ 尚未找到 APK 文件"
    echo "💡 請先執行: ./build_android.sh release"
    exit 1
fi

echo "✅ 找到以下 APK 文件："
echo ""

for apk in $APK_FILES; do
    FILE_SIZE=$(du -h "$apk" | cut -f1)
    FILE_DATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$apk")
    echo "📱 $apk"
    echo "   📊 大小: $FILE_SIZE"
    echo "   📅 日期: $FILE_DATE"
    echo ""
done

# 顯示最新的 APK
LATEST_APK=$(ls -t build/app/outputs/flutter-apk/*.apk 2>/dev/null | head -1)

if [ -n "$LATEST_APK" ]; then
    echo "🎯 最新的 APK:"
    echo "   $LATEST_APK"
    echo ""
    echo "📋 完整路徑:"
    echo "   $(pwd)/$LATEST_APK"
    echo ""
    echo "💡 分享方式："
    echo "   1. 直接複製文件到其他設備"
    echo "   2. 使用 AirDrop (Mac)"
    echo "   3. 上傳到雲端硬碟（Google Drive、Dropbox）"
    echo "   4. 通過 Email 發送"
    echo "   5. 使用即時通訊軟體（Line、WeChat）"
fi
