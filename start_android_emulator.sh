#!/bin/bash

# Android 模擬器啟動腳本
echo "🤖 啟動 Android 模擬器配置..."

# 檢查後端服務
echo "🔍 檢查後端服務..."
if curl -s http://localhost:8888/here4help/backend/api/auth/login.php > /dev/null; then
    echo "✅ 後端服務運行正常"
else
    echo "❌ 後端服務未運行，請先啟動後端服務"
    exit 1
fi

# 檢查 Socket.IO 服務
echo "🔍 檢查 Socket.IO 服務..."
if curl -s http://localhost:3001 > /dev/null; then
    echo "✅ Socket.IO 服務運行正常"
else
    echo "❌ Socket.IO 服務未運行，請先啟動 Socket.IO 服務"
    exit 1
fi

# 啟動 Flutter Android 模擬器
echo "🚀 啟動 Flutter Android 模擬器..."
flutter run -d 'emulator-5554' \
  --dart-define=ENVIRONMENT=development \
  --dart-define=API_BASE_URL=http://127.0.0.1:8888/here4help \
  --dart-define=SOCKET_URL=http://127.0.0.1:3001 \
  --dart-define=IMAGE_BASE_URL=http://127.0.0.1:8888/here4help \
  --dart-define=DEBUG_MODE=true \
  --dart-define=LOG_LEVEL=debug \
  --dart-define=ANDROID_EMULATOR=true
