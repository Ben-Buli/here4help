#!/bin/bash

# Xcode 緩存清理腳本
# 用於修復 "unable to initiate PIF transfer session" 錯誤
# 用法: ./scripts/clean_xcode_cache.sh

set -euo pipefail

echo "🧹 開始清理 Xcode 緩存..."

# 1. 關閉 Xcode 和相關進程
echo "📱 關閉 Xcode 和相關進程..."
killall Xcode 2>/dev/null || true
killall com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null || true
killall com.apple.dt.SKAgent 2>/dev/null || true
killall com.apple.ibtoold 2>/dev/null || true

# 等待進程完全關閉
echo "⏳ 等待進程關閉..."
sleep 3

# 2. 清理 DerivedData
echo "🗑️  清理 DerivedData..."
if [ -d ~/Library/Developer/Xcode/DerivedData ]; then
    rm -rf ~/Library/Developer/Xcode/DerivedData/*
    echo "✅ DerivedData 已清理"
else
    echo "ℹ️  DerivedData 目錄不存在，跳過"
fi

# 3. 清理模組緩存
echo "🗑️  清理模組緩存..."
if [ -d ~/Library/Developer/Xcode/ModuleCache.noindex ]; then
    rm -rf ~/Library/Developer/Xcode/ModuleCache.noindex/*
    echo "✅ 模組緩存已清理"
else
    echo "ℹ️  模組緩存目錄不存在，跳過"
fi

# 4. 清理 Xcode 緩存
echo "🗑️  清理 Xcode 緩存..."
if [ -d ~/Library/Caches/com.apple.dt.Xcode ]; then
    rm -rf ~/Library/Caches/com.apple.dt.Xcode/*
    echo "✅ Xcode 緩存已清理"
else
    echo "ℹ️  Xcode 緩存目錄不存在，跳過"
fi

# 5. 清理 Archives（可選，如果需要保留舊的 Archive 可以註解掉）
read -p "是否清理 Archives？這會刪除所有舊的 Archive 檔案 (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d ~/Library/Developer/Xcode/Archives ]; then
        rm -rf ~/Library/Developer/Xcode/Archives/*
        echo "✅ Archives 已清理"
    else
        echo "ℹ️  Archives 目錄不存在，跳過"
    fi
fi

# 6. 清理專案建置資料（可選）
read -p "是否清理專案的 build 資料夾？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d ios/build ]; then
        rm -rf ios/build
        echo "✅ 專案 build 資料夾已清理"
    else
        echo "ℹ️  專案 build 資料夾不存在，跳過"
    fi
fi

echo ""
echo "✅ Xcode 緩存清理完成！"
echo ""
echo "📋 下一步："
echo "1. 重新開啟 Xcode: open ios/Runner.xcworkspace"
echo "2. 等待 Xcode 完成索引（可能需要幾分鐘）"
echo "3. 嘗試 Product → Clean Build Folder (Shift+Cmd+K)"
echo "4. 然後嘗試 Product → Archive"
echo ""

