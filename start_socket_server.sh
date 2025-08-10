#!/bin/bash

# Here4Help Socket.IO 服務器啟動腳本

echo "🚀 Starting Here4Help Socket.IO Server..."

# 檢查 Node.js 是否安裝
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first."
    exit 1
fi

# 進入 backend/socket 目錄
cd backend/socket

# 檢查是否有 node_modules
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# 啟動 Socket.IO 服務器
echo "🔌 Starting Socket.IO server on port 3001..."
npm start

# 如果沒有 npm start 腳本，直接運行 server.js
if [ $? -ne 0 ]; then
    echo "📝 Running server.js directly..."
    node server.js
fi