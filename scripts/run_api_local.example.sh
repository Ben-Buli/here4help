#!/bin/bash

# 啟動本地 API 服務腳本範例
# 複製此檔案為 run_api_local.sh 並根據需要修改

echo "🚀 啟動本地 API 服務..."

# 檢查 MAMP 是否運行
if ! curl -s http://localhost:8888 > /dev/null; then
    echo "❌ MAMP 未運行，請先啟動 MAMP"
    echo "💡 提示：開啟 MAMP 應用程式並啟動 Apache + MySQL"
    exit 1
fi

# 檢查資料庫連接
echo "🔍 檢查資料庫連接..."
if curl -s "http://localhost:8888/here4help/backend/api/auth/login.php" > /dev/null; then
    echo "✅ API 服務正常運行在 http://localhost:8888"
else
    echo "❌ API 服務無法訪問"
    exit 1
fi

echo "✅ 本地 API 服務已準備就緒！"
echo "🌐 訪問地址：http://localhost:8888/here4help/backend/api"
